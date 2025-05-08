#!/bin/bash
set -ex

# Setup microsoft packages repository for moby
# Download the repository configuration package
curl https://packages.microsoft.com/config/ubuntu/24.04/prod.list > ./microsoft-prod.list
# Copy the generated list to the sources.list.d directory
cp ./microsoft-prod.list /etc/apt/sources.list.d/
# Install the Microsoft GPG public key
curl https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > microsoft-prod.gpg
cp ./microsoft-prod.gpg /etc/apt/trusted.gpg.d/
cp ./microsoft-prod.gpg /usr/share/keyrings/

#apt-get install packages

$UBUNTU_COMMON_DIR/install_utils.sh
