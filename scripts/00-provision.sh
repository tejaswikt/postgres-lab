#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

PG_VERSION=$1

echo "================================================================="
echo " Starting Post-Provisioning Environment Setup..."
echo " Target PostgreSQL Version: ${PG_VERSION}"
echo "================================================================="

# --- Step 1: Install PostgreSQL Repositories ---
echo "Installing PostgreSQL ${PG_VERSION} repository..."
dnf install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm

echo "Disabling built-in PostgreSQL dnf module..."
dnf -qy module disable postgresql


# --- Step 2: Install & Initialize PostgreSQL ---
echo "Installing PostgreSQL ${PG_VERSION} server packages..."
dnf install -y postgresql${PG_VERSION}-server postgresql${PG_VERSION}-contrib

echo "Initializing PostgreSQL ${PG_VERSION} database..."
/usr/pgsql-${PG_VERSION}/bin/postgresql-${PG_VERSION}-setup initdb


# --- Step 3: Configure and Start PostgreSQL Service ---
echo "Starting and enabling PostgreSQL ${PG_VERSION} service..."
systemctl enable --now postgresql-${PG_VERSION}


# --- Step 4: OpenSSH Client & Server Compatibility Fix (Run Last) ---
echo "PostgreSQL installed. Applying OpenSSH compatibility fix to reset library matches..."
# Reinstall and update to ensure clean, compatible modern SSH libraries post-Postgres setup
sudo dnf reinstall openssh-clients openssh-server -y
sudo dnf update openssh-clients openssh-server -y

# Restart SSH service to apply any updated security parameters/libraries
sudo systemctl restart sshd
echo "OpenSSH libraries updated and service restarted successfully."

echo "================================================================="
echo " PostgreSQL ${PG_VERSION} installation & SSH reset completed successfully!"
echo "================================================================="

# --- Step 3.5: Install pg_wait_sampling, pg_cron & pgBadger ---
echo "Installing pg_wait_sampling for PostgreSQL ${PG_VERSION}..."
dnf install -y pg_wait_sampling_${PG_VERSION}

sudo dnf install -y pg_cron_${PG_VERSION}

echo "Downloading and installing pgBadger v13.2..."
# Download to /tmp to keep the home directory clean
curl -L https://github.com/darold/pgbadger/archive/refs/tags/v13.2.tar.gz -o /tmp/pgbadger.tar.gz

# Extract and install pgBadger
tar -zxvf /tmp/pgbadger.tar.gz -C /tmp/
sudo cp /tmp/pgbadger-13.2/pgbadger /usr/local/bin/
sudo chmod +x /usr/local/bin/pgbadger

# Cleanup temporary installation files
rm -rf /tmp/pgbadger.tar.gz /tmp/pgbadger-13.2
echo "pgBadger installation completed successfully!"


# --- Step 3.6: Download and Install pg_profile ---
echo "Downloading pg_profile v4.11..."
wget https://github.com/zubkov-andrei/pg_profile/releases/download/4.11/pg_profile--4.11.tar.gz -O /tmp/pg_profile--4.11.tar.gz

echo "Extracting pg_profile to PostgreSQL ${PG_VERSION} extension directory..."
sudo tar xzf /tmp/pg_profile--4.11.tar.gz --directory /usr/pgsql-${PG_VERSION}/share/extension

echo "Cleaning up pg_profile temporary file..."
rm -f /tmp/pg_profile--4.11.tar.gz