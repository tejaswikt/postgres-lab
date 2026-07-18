#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

INPUT_VERSION=$1

# 1. Dynamically parse Major vs. Specific Minor versions
if [[ "$INPUT_VERSION" == *.* ]]; then
    PG_MAJOR=$(echo "$INPUT_VERSION" | cut -d'.' -f1)
    PG_FULL="$INPUT_VERSION"
else
    PG_MAJOR="$INPUT_VERSION"
    PG_FULL="$INPUT_VERSION*" 
fi

echo "================================================================="
echo " Starting Post-Provisioning Environment Setup..."
echo " Target Major Version (Paths): ${PG_MAJOR}"
echo " Target Package Constraint:    ${PG_FULL}"
echo "================================================================="

# --- Step 1: Install PostgreSQL Repositories ---
echo "Installing PostgreSQL repository..."
dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm

echo "Disabling built-in PostgreSQL dnf module..."
dnf -qy module disable postgresql

# --- Step 2: Install & Initialize PostgreSQL with explicit matching ---
echo "Installing PostgreSQL server packages matching version: ${PG_FULL}..."
dnf install -y postgresql${PG_MAJOR}-server-${PG_FULL} postgresql${PG_MAJOR}-contrib-${PG_FULL}

echo "Initializing PostgreSQL ${PG_MAJOR} database..."
/usr/pgsql-${PG_MAJOR}/bin/postgresql-${PG_MAJOR}-setup initdb

# --- Step 3: Configure and Start PostgreSQL Service ---
echo "Starting and enabling PostgreSQL ${PG_MAJOR} service..."
systemctl enable --now postgresql-${PG_MAJOR}

# --- Step 4: OpenSSH Client & Server Compatibility Fix ---
echo "Applying OpenSSH compatibility fix..."
sudo dnf reinstall openssh-clients openssh-server -y
sudo dnf update openssh-clients openssh-server -y
sudo systemctl restart sshd

# --- Step 5: Install Version-Locked Extensions ---
echo "Installing pg_wait_sampling matching PostgreSQL ${PG_MAJOR}..."
dnf install -y pg_wait_sampling_${PG_MAJOR}*

echo "Installing pg_cron matching PostgreSQL ${PG_MAJOR}..."
dnf install -y pg_cron_${PG_MAJOR}*

# --- Step 6: Install Independent Tooling (pgBadger) ---
echo "Downloading and installing pgBadger v13.2..."
curl -L https://github.com/darold/pgbadger/archive/refs/tags/v13.2.tar.gz -o /tmp/pgbadger.tar.gz
tar -zxvf /tmp/pgbadger.tar.gz -C /tmp/
sudo cp /tmp/pgbadger-13.2/pgbadger /usr/local/bin/
sudo chmod +x /usr/local/bin/pgbadger
rm -rf /tmp/pgbadger.tar.gz /tmp/pgbadger-13.2

# --- Step 7: Download and Install pg_profile ---
echo "Downloading pg_profile v4.11..."
wget https://github.com/zubkov-andrei/pg_profile/releases/download/4.11/pg_profile--4.11.tar.gz -O /tmp/pg_profile--4.11.tar.gz

echo "Extracting pg_profile to PostgreSQL ${PG_MAJOR} extension directory..."
sudo tar xzf /tmp/pg_profile--4.11.tar.gz --directory /usr/pgsql-${PG_MAJOR}/share/extension

# Clean up
rm -f /tmp/pg_profile--4.11.tar.gz

echo "================================================================="
echo " Environment setup completed successfully!"
echo "================================================================="