#!/bin/bash
# =========================================================================
# DEPLOY NEW LAB ENVIRONMENT WRAPPER
# Runs natively as the 'postgres' user via Vagrant
# =========================================================================

set -e # Exit immediately if any command fails

RUN_USER=$1

# If running as root (due to privileged: true), switch to the postgres user immediately
if [ "$(id -u)" -eq 0 ] && [ -n "${RUN_USER}" ]; then
    echo "Switching execution user to '${RUN_USER}'..."
    exec su -s /bin/bash -l "${RUN_USER}" -c "$0"
fi

echo "=== STEP 1: Terminating active connections to creditcards database ==="
psql -d postgres -c "
SELECT pg_terminate_backend(pg_stat_activity.pid)
FROM pg_stat_activity
WHERE pg_stat_activity.datname = 'creditcards'
  AND pid <> pg_backend_pid();"

echo "=== STEP 2: Dropping existing creditcards database ==="
psql -d postgres -c "DROP DATABASE IF EXISTS creditcards;"

echo "=== STEP 3: Creating fresh creditcards database ==="
psql -d postgres -c "CREATE DATABASE creditcards;"

echo "=== STEP 4: Executing schema definition and seeding workload ==="

SQL_FILE="03-setup_schema.sql"

# 1. Resolve path to SQL file dynamically
if [ -f "/vagrant_scripts/${SQL_FILE}" ]; then
    SCHEMA_PATH="/vagrant_scripts/${SQL_FILE}"
elif [ -f "./${SQL_FILE}" ]; then
    SCHEMA_PATH="./${SQL_FILE}"
else
    echo "ERROR: Could not find ${SQL_FILE}!" >&2
    exit 1
fi

echo "Loading schema from: ${SCHEMA_PATH}"
psql -d creditcards -f "${SCHEMA_PATH}"


echo "=== STEP 5: Creating Extensions in 'creditcards' Database ==="
psql -d creditcards -c "CREATE EXTENSION IF NOT EXISTS pg_wait_sampling;"
psql -d creditcards -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"


echo "=== STEP 6: Setting up 'pg_profile' in 'postgres' Database ==="
psql -d postgres -c "CREATE EXTENSION IF NOT EXISTS dblink;"
psql -d postgres -c "CREATE EXTENSION IF NOT EXISTS pg_stat_statements;"
psql -d postgres -c "CREATE SCHEMA IF NOT EXISTS profile;"
psql -d postgres -c "CREATE EXTENSION IF NOT EXISTS pg_profile SCHEMA profile;"


echo "=== STEP 7: Registering 'creditcards' inside pg_profile ==="
psql -d postgres << 'EOF'
-- Ensure the server profile exists in the repository
INSERT INTO profile.servers (server_name, connstr, enabled)
VALUES ('creditcards', 'dbname=creditcards host=127.0.0.1', true)
ON CONFLICT (server_name) DO NOTHING;

-- Safely update settings with pg_wait_sampling
UPDATE profile.servers
SET srv_settings = '{"pg_wait_sampling": "true"}'::jsonb
WHERE server_name = 'creditcards';
EOF

echo "========================================================================="
echo " SUCCESS: Lab is fully loaded, extensions are active, and pg_profile is set!"
echo "========================================================================="
