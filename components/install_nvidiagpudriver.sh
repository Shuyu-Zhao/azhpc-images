#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Install NVIDIA driver
nvidia_metadata=$(get_component_config "nvidia")
nvidia_driver_metadata=$(jq -r '.driver' <<< $nvidia_metadata)
NVIDIA_DRIVER_VERSION=$(jq -r '.version' <<< $nvidia_driver_metadata)
NVIDIA_DRIVER_SHA256=$(jq -r '.sha256' <<< $nvidia_driver_metadata)
NVIDIA_DRIVER_URL=https://us.download.nvidia.com/tesla/${NVIDIA_DRIVER_VERSION}/NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run
kernel_version=$(uname -r | sed 's/\-/./g')

if [ "$1" = "V100" ]; then
    KERNEL_MODULE_TYPE="proprietary"
    # Install Nvidia GPU propreitary variant for V100 and older SKUs
    AL3_GPU_DRIVER_PACKAGES="cuda-$NVIDIA_DRIVER_VERSION-1_$kernel_version.x86_64"
else
    KERNEL_MODULE_TYPE="open"
    # Install Nvidia GPU open source variant for A100, H100 
    AL3_GPU_DRIVER_PACKAGES="cuda-open-$NVIDIA_DRIVER_VERSION-1_$kernel_version.x86_64"
fi

if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    curl https://packages.microsoft.com/azurelinux/3.0/prod/nvidia/x86_64/config.repo > /etc/yum.repos.d/azurelinux-nvidia-prod.repo
    tdnf install -y $AL3_GPU_DRIVER_PACKAGES
    # Temp disable NVIDIA driver updates
    mkdir -p /etc/tdnf/locks.d
    echo cuda >> /etc/tdnf/locks.d/nvidia.conf
else
    download_and_verify $NVIDIA_DRIVER_URL ${NVIDIA_DRIVER_SHA256}
    bash NVIDIA-Linux-x86_64-${NVIDIA_DRIVER_VERSION}.run --silent --dkms --kernel-module-type=${KERNEL_MODULE_TYPE}
    if [[ $DISTRIBUTION == almalinux* ]]; then
        dkms install --no-depmod -m nvidia -v ${NVIDIA_DRIVER_VERSION} -k `uname -r` --force
    fi
    # load the nvidia-peermem coming as a part of NVIDIA GPU driver
    # Reference - https://download.nvidia.com/XFree86/Linux-x86_64/510.85.02/README/nvidia-peermem.html
    modprobe nvidia-peermem
    # verify if loaded
    lsmod | grep nvidia_peermem
fi
write_component_version "NVIDIA" ${NVIDIA_DRIVER_VERSION}

touch /etc/modules-load.d/nvidia-peermem.conf
echo "nvidia_peermem" >> /etc/modules-load.d/nvidia-peermem.conf

$COMPONENT_DIR/install_gdrdrv.sh

# Install nvidia fabric manager (required for ND96asr_v4)
$COMPONENT_DIR/install_nvidia_fabric_manager.sh

# cleanup downloaded files
rm -rf *.run *tar.gz *.rpm
rm -rf -- */