#!/bin/bash

# Define your VM box and configuration
UBUNTU_VERSION="ubuntu/focal64"
MASTER_IP="192.168.56.10"
SLAVE_IP="192.168.56.11"

# Add the 'focal64' box to Vagrant (if not already added)
if [[ ! $(vagrant box list | grep "$UBUNTU_VERSION") ]]; then
  vagrant box add --name "$UBUNTU_VERSION" "$UBUNTU_VERSION"
fi

# Function to install LAMP stack
install_lamp_stack() {
  # Update and install necessary packages
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y apache2 mysql-server php libapache2-mod-php

  # Ensure Apache is running and set to start on boot
  systemctl enable apache2
  systemctl start apache2

  # Secure MySQL installation and initialize with a default user and password
  mysql_secure_installation <<EOF
  n
  y
  y
  y
  y
EOF
}

# Create a directory for the 'Master' node
mkdir -p master
cd master

# Create a Vagrantfile for the 'Master' node
cat > Vagrantfile <<EOF
Vagrant.configure("2") do |config|
  config.vm.box = "$UBUNTU_VERSION"
  config.vm.network "private_network", type: "dhcp"
  config.vm.network "private_network", ip: "$MASTER_IP"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 1024
    vb.cpus = 1
  end
  config.vm.provision "shell", inline: <<-SHELL
    $(install_lamp_stack)
    # Display an overview of running processes
    ps aux
  SHELL
end
EOF

# Initialize and start the 'Master' node
vagrant up

# Generate an SSH key for the 'altschool' user on the Master node
vagrant ssh -c "sudo -u altschool ssh-keygen -t rsa -N '' -f /home/altschool/.ssh/id_rsa"

# Copy the public key to the Slave node for passwordless SSH
vagrant ssh -c "sudo -u altschool ssh-copy-id -i /home/altschool/.ssh/id_rsa.pub altschool@$SLAVE_IP"

# Transfer data from Master to Slave
vagrant ssh -c "sudo -u altschool scp -r /mnt/altschool altschool@$SLAVE_IP:/mnt/altschool/slave"

# Return to the parent directory
cd ..

# Create a directory for the 'Slave' node
mkdir -p slave
cd slave

# Create a Vagrantfile for the 'Slave' node
cat > Vagrantfile <<EOF
Vagrant.configure("2") do |config|
  config.vm.box = "$UBUNTU_VERSION"
  config.vm.network "private_network", ip: "$SLAVE_IP"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = 1024
    vb.cpus = 1
  end
  config.vm.provision "shell", inline: <<-SHELL
    $(install_lamp_stack)
  SHELL
end
EOF

# Initialize and start the 'Slave' node
vagrant up

# Return to the parent directory
cd ..

# Clean up and SSH into the 'Master' node
vagrant ssh -c "cd /vagrant/master && vagrant ssh"
