# Automated PostgreSQL Lab Environment on Oracle Linux 9

This repository contains a modular, declarative Vagrant environment designed to deploy and provision PostgreSQL lab servers on **Oracle Linux 9 (OEL9)** using **VirtualBox**.

Following infrastructure-as-code (IaC) best practices inspired by ORACLE-BASE, this setup cleanly separates configuration parameters (CPU, Memory, IP, and PostgreSQL versions) from the execution logic, allowing single-point-of-control deployments.

---

## 🏗️ Architecture Overview

The setup splits configuration and execution into separate, clean domains:

```text
postgres-labs-pt/
├── .gitignore               # Excludes local Vagrant cache/state files
├── Vagrantfile              # The main orchestration engine
├── README.md                # The instructions for your readers
├── config/
│   └── vagrant.yml          # Example node configurations
└── scripts/
    ├── 00-provision.sh      # OS & Package installation
    ├── 01-setup_config_file.sh # Modular conf.d & extension preloads
    ├── 02-deploy_new_lab.sh # Database schema, seeds, & extension activation
    └── 03-setup_config_file.sql # The 10-million row dataset
