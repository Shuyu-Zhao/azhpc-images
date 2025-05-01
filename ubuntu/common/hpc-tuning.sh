#!/bin/bash
set -ex

# Install Dependencies
apt install -y python3-netifaces
apt install -y python3-yaml

# Disable some unneeded services by default (administrators can re-enable if desired)
systemctl disable ufw

$COMMON_DIR/hpc-tuning.sh

# Azure Linux Agent
$UBUNTU_COMMON_DIR/install_waagent.sh
