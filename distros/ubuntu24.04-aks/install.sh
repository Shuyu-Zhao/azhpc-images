#!/bin/bash
set -ex

# Check if arguments are passed
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Error: Missing arguments. Please provide both GPU type (NVIDIA/AMD) and SKU."
    exit 1
fi

export GPU=$1
export SKU=$2

if [[ "$#" -gt 0 ]]; then
   if [[ "$GPU" != "NVIDIA" && "$GPU" != "AMD" ]]; then
       echo "Error: Invalid GPU type. Please specify 'NVIDIA' or 'AMD'."
       exit 1
    fi
fi

source ../../utils/set_properties.sh
export DISTRIBUTION=$DISTRIBUTION-aks

./install_utils.sh

# install DOCA OFED
$COMPONENT_DIR/install_doca.sh

if [ "$GPU" = "NVIDIA" ]; then
    # install nvidia gpu driver
    $COMPONENT_DIR/install_nvidiagpudriver.sh "$SKU"

    # Install DCGM
    $COMPONENT_DIR/install_dcgm.sh
fi

# cleanup downloaded tarballs - clear some space
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*
rm -rf /var/intel/ /var/cache/*
rm -Rf -- */

# Azure Linux Agent
$COMPONENT_DIR/install_waagent.sh

# optimizations
# $COMPONENT_DIR/hpc-tuning.sh

# add udev rule
#$COMPONENT_DIR/add-udev-rules.sh

# disable cloud-init
#$COMPONENT_DIR/disable_cloudinit.sh

# diable auto kernel updates
#./disable_auto_upgrade.sh

# Disable Predictive Network interface renaming
#./disable_predictive_interface_renaming.sh

# clear history
# Uncomment the line below if you are running this on a VM
# $UTILS_DIR/clear_history.sh
