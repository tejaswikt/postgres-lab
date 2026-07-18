#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Extract arguments passed from Vagrantfile
RUN_USER=$1
PG_VERSION=$2

# If running as root (due to privileged: true), switch to the postgres user immediately
if [ "$(id -u)" -eq 0 ] && [ -n "${RUN_USER}" ]; then
    echo "Switching execution user to '${RUN_USER}'..."
    exec su -s /bin/bash -l "${RUN_USER}" -c "$0 '' '${PG_VERSION}'"
fi

# =========================================================================
# ONE-SHOT CONFIGURATION RESET & POPULATION
# Run inside: CONF_D_DIR as the postgres user
# =========================================================================

# 1. Dynamically discover active PostgreSQL environment paths (runs natively as postgres)
CONFIG_FILE=$(psql -At -c "show config_file;")
CONFIG_DIR=$(dirname "${CONFIG_FILE}")
CONF_D_DIR="${CONFIG_DIR}/conf.d"

echo "=== System Discovery ==="
echo "Active Config File:  ${CONFIG_FILE}"
echo "Target conf.d Dir:   ${CONF_D_DIR}"
echo "Detected PG Version: ${PG_VERSION}"
echo "========================="

# 2. Ensure target directory exists and switch to it
mkdir -p "${CONF_D_DIR}"
cd "${CONF_D_DIR}"

echo "=== 1. Emptying/Creating configuration files ==="
> 00-extensions.conf
> 01-performance.conf
> 02-logging.conf
> 03-vacuum.conf
> 04-wal.conf

echo "=== 2. Writing 00-extensions.conf ==="
cat << 'EOF' > 00-extensions.conf
# ============================================================
# Shared Libraries and Extensions
# ============================================================
shared_preload_libraries = 'pg_stat_statements, pg_wait_sampling, pg_cron'
EOF

echo "=== 3. Writing 01-performance.conf ==="
cat << 'EOF' > 01-performance.conf
# ============================================================
# PostgreSQL Performance & Extension Configuration
# Purpose: pg_profile & pg_stat_statements engine dependencies
# ============================================================

# pg_stat_statements Config
pg_stat_statements.max = 10000
pg_stat_statements.track = all
pg_stat_statements.track_planning = on
pg_stat_statements.save = on

# Core Engine Statistics Tracking
track_activities = on
track_counts = on
track_io_timing = on
track_wal_io_timing = on

# pg_cron Config
cron.database_name = 'postgres'
cron.timezone = 'Europe/Amsterdam'
EOF

echo "=== 4. Writing 02-logging.conf ==="
cat << 'EOF' > 02-logging.conf
# ============================================================
# PostgreSQL Logging Configuration
# Purpose: Production-grade performance troubleshooting logs
# ============================================================

# Log Storage and Destination
logging_collector = on
log_destination = 'stderr'
log_directory = 'log'

# Naming and Rotation
log_filename = 'postgresql-%Y-%m-%d_%H%M%S.log'
log_rotation_age = 1d
log_rotation_size = 1000MB
log_truncate_on_rotation = off

# Log Content Identity
log_line_prefix = '%m [%p] %q%u@%d [query_id=%Q] app=%a client=%h '
compute_query_id = on

# Slow Query Logging
log_min_duration_statement = 1000ms

# Lock, Wait, and Deadlock Auditing
log_lock_waits = on
deadlock_timeout = '1s'

# Temporary File / Spill Logging
log_temp_files = 0

# Checkpoint Logging
log_checkpoints = on

# Autovacuum Logging
log_autovacuum_min_duration = 100ms

# Error Statement Logging
log_min_error_statement = error

# General Message Level
log_min_messages = warning

# Connection Logging
log_connections = on
log_disconnections = on

# Statement Logging
log_statement = 'none'
log_duration = off
EOF

echo "=== 5. Writing 03-vacuum.conf (Declarative Placeholder) ==="
cat << 'EOF' > 03-vacuum.conf
# ============================================================
# Autovacuum Resource Allocation
# Left at default parameters for active lab tuning scenarios
# ============================================================
# autovacuum_max_workers = 3
# autovacuum_vacuum_scale_factor = 0.2
# autovacuum_analyze_scale_factor = 0.1
EOF

echo "=== 6. Writing 04-wal.conf (Declarative Placeholder) ==="
cat << 'EOF' > 04-wal.conf
# ============================================================
# Write-Ahead Logging (WAL) settings
# Left at default parameters for checkpoint frequency labs
# ============================================================
# max_wal_size = 1GB
# min_wal_size = 80MB
# checkpoint_completion_target = 0.9
EOF

echo "========================================================================="
echo " CONFIGURATION REBUILD COMPLETE! "
echo " Restarting the database to apply changes..."
# Dynamically parse the major version out of the argument (e.g., '16.3' -> '16')
PG_MAJOR=$(echo "${PG_VERSION}" | cut -d'.' -f1)

# Restart using the absolute binary path and discovered config directory
/usr/pgsql-${PG_MAJOR}/bin/pg_ctl restart -D "${CONFIG_DIR}"

echo " Database successfully restarted and ready for schema deployments!"
echo "========================================================================="