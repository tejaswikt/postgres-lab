# Automated PostgreSQL Lab Environment on Oracle Linux 9

This repository contains a modular, declarative Vagrant environment designed to deploy and provision PostgreSQL lab servers on **Oracle Linux 9 (OEL9)** using **VirtualBox**.

Following infrastructure-as-code (IaC) best practices inspired by ORACLE-BASE, this setup cleanly separates configuration parameters (CPU, Memory, IP, and PostgreSQL versions) from the execution logic, allowing single-point-of-control deployments.

---

## 🏗️ Architecture Overview

The setup splits configuration and execution into separate, clean domains:

```text
postgres-lab/
├── config/
│   └── vagrant.yml       # Host & Software configurations (declarative)
├── scripts/
│   └── provision.sh      # Shell script to automate OS and DB provisioning
├── Vagrantfile           # Ruby engine parsing YAML & launching VirtualBox VMs
└── README.md             # Project documentation (this file)
