# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'yaml'

# Dynamically locate config file relative to this Vagrantfile's directory
config_path = File.expand_path("../config/vagrant.yml", __FILE__)

if File.exist?(config_path)
  conf = YAML.load_file(config_path)
else
  abort "Configuration file not found at: #{config_path}\nPlease create it before running 'vagrant up'."
end

Vagrant.configure("2") do |config|
  
  # Share the configuration and scripts folders inside the VM
  config.vm.synced_folder "./config", "/vagrant_config"
  config.vm.synced_folder "./scripts", "/vagrant_scripts"

  # Loop through each node defined in the YAML file
  conf['nodes'].each do |node|
    config.vm.define node['name'] do |node_config|
      
      node_config.vm.box = conf['shared']['box']
      node_config.vm.hostname = node['name']
      node_config.vm.network "private_network", ip: node['ip']

      node_config.vm.provider "virtualbox" do |vb|
        vb.name   = node['name']
        vb.memory = node['mem']
        vb.cpus   = node['cpu']
        vb.customize ["modifyvm", :id, "--ioapic", "on"]
      end

      # =======================================================================
      # STEP 0: Main Server & Dependency Provisioner (Runs as Root)
      # =======================================================================
      node_config.vm.provision "shell", 
        path: "scripts/00-provision.sh", 
        args: [conf['shared']['postgres_version']]

      # =======================================================================
      # STEP 1: Configure PostgreSQL conf.d Modules (Runs as postgres)
      # =======================================================================
      node_config.vm.provision "shell", 
        path: "scripts/01-setup_config_file.sh", 
        privileged: true, # Runs as root first so it can access the script safely
        args: ["postgres", conf['shared']['postgres_version']] # Passes "postgres" to switch users internally

      # =======================================================================
      # STEP 2: Schema Setup and High-Volume Seeding (Runs as postgres)
      # =======================================================================
      node_config.vm.provision "shell", 
        path: "scripts/02-deploy_new_lab.sh", 
        privileged: true, # Runs as root first
        args: ["postgres"] # Passes "postgres" to switch users internally
    end
  end
end