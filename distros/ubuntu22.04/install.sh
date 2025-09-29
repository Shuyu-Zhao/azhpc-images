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

# remove packages requiring Ubuntu Pro for security updates
./remove_unused_packages.sh

./install_utils.sh

# update cmake
$COMPONENT_DIR/install_cmake.sh

# install Lustre client
# $COMPONENT_DIR/install_lustre_client.sh

# install DOCA OFED
$COMPONENT_DIR/install_doca.sh

# install PMIX
$COMPONENT_DIR/install_pmix.sh

# install mpi libraries
$COMPONENT_DIR/install_mpis.sh

if [ "$GPU" = "NVIDIA" ]; then
    # install nvidia gpu driver
    $COMPONENT_DIR/install_nvidiagpudriver.sh "$SKU"
    
    # Install NCCL
    $COMPONENT_DIR/install_nccl.sh
    
    # Install NVIDIA docker container
    $COMPONENT_DIR/install_docker.sh
systemsctl status docker

    # Install DCGM
    $COMPONENT_DIR/install_dcgm.sh
systemsctl status docker

fi

if [ "$GPU" = "AMD" ]; then
    # Set up docker
    apt-get install -y moby-engine
    systemctl enable docker
    systemctl restart docker

    #install rocm software stack
    $COMPONENT_DIR/install_rocm.sh    
    #install rccl and rccl-tests
    $COMPONENT_DIR/install_rccl.sh
fi

# install AMD libs
$COMPONENT_DIR/install_amd_libs.sh
systemsctl status docker

# install Intel libraries
$COMPONENT_DIR/install_intel_libs.sh
systemsctl status docker

# cleanup downloaded tarballs - clear some space
rm -rf *.tgz *.bz2 *.tbz *.tar.gz *.run *.deb *_offline.sh
rm -rf /tmp/MLNX_OFED_LINUX* /tmp/*conf*
rm -rf /var/intel/ /var/cache/*
rm -Rf -- */

# optimizations
$COMPONENT_DIR/hpc-tuning.sh
systemsctl status docker

# Install AZNFS Mount Helper
$COMPONENT_DIR/install_aznfs.sh
systemsctl status docker

# install diagnostic script
$COMPONENT_DIR/install_hpcdiag.sh
systemsctl status docker

# install monitor tools
$COMPONENT_DIR/install_monitoring_tools.sh
systemsctl status docker

# install persistent rdma naming
$COMPONENT_DIR/install_azure_persistent_rdma_naming.sh
systemsctl status docker

# copy test file
$COMPONENT_DIR/copy_test_file.sh
systemsctl status docker

# install Azure/NHC Health Checks
$COMPONENT_DIR/install_health_checks.sh "$GPU"
systemsctl status docker

# disable cloud-init
$COMPONENT_DIR/disable_cloudinit.sh
systemsctl status docker

# SKU Customization
$COMPONENT_DIR/setup_sku_customizations.sh
systemsctl status docker

# scan vulnerabilities using Trivy
$COMPONENT_DIR/trivy_scan.sh
systemsctl status docker

# diable auto kernel updates
./disable_auto_upgrade.sh
systemsctl status docker

# Disable Predictive Network interface renaming
./disable_predictive_interface_renaming.sh
systemsctl status docker

# clear history
# Uncomment the line below if you are running this on a VM
# $UTILS_DIR/clear_history.sh
