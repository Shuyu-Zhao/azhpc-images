#!/bin/bash
set -ex

# Setup microsoft packages repository
curl -sSL -O https://packages.microsoft.com/config/ubuntu/24.04/packages-microsoft-prod.deb
dpkg -i packages-microsoft-prod.deb
rm packages-microsoft-prod.deb

apt-get update
apt-get -y install build-essential
apt-get -y install dkms \
                   jq 
                   
echo ib_ipoib | sudo tee /etc/modules-load.d/ib_ipoib.conf