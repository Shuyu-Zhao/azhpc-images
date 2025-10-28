#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

gdrcopy_metadata=$(get_component_config "gdrcopy")
GDRCOPY_VERSION=$(jq -r '.version' <<< $gdrcopy_metadata)
GDRCOPY_COMMIT=$(jq -r '.commit' <<< $gdrcopy_metadata)
GDRCOPY_DISTRIBUTION=$(jq -r '.distribution' <<< $gdrcopy_metadata)

if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    echo "Skip"
    exit 0
else
    cuda_metadata=$(get_component_config "cuda")
    CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)     
    if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
        DOWNLOAD_URL="https://developer.download.nvidia.com/compute/redist/gdrcopy/CUDA%20${CUDA_DRIVER_VERSION}/${GDRCOPY_DISTRIBUTION,,}/x64/gdrdrv-dkms_${GDRCOPY_VERSION}_amd64.${GDRCOPY_DISTRIBUTION}.deb"
        wget $DOWNLOAD_URL
        dpkg -i gdrdrv-dkms_${GDRCOPY_VERSION}_amd64.${GDRCOPY_DISTRIBUTION}.deb
    elif [[ $DISTRIBUTION == almalinux* ]]; then
        DOWNLOAD_URL="https://developer.download.nvidia.com/compute/redist/gdrcopy/CUDA%20${CUDA_DRIVER_VERSION}/${GDRCOPY_DISTRIBUTION,,}/x64/gdrcopy-kmod-${GDRCOPY_VERSION}dkms.${GDRCOPY_DISTRIBUTION}.noarch.rpm"
        wget $DOWNLOAD_URL
        rpm -Uvh gdrcopy-kmod-${GDRCOPY_VERSION}dkms.${GDRCOPY_DISTRIBUTION}.noarch.rpm
    fi
    popd
fi
write_component_version "GDRDRV" ${GDRCOPY_VERSION}
