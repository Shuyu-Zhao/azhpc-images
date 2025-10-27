#!/bin/bash
set -ex

source ${UTILS_DIR}/utilities.sh

# Set the driver versions
cuda_metadata=$(get_component_config "cuda")
CUDA_DRIVER_VERSION=$(jq -r '.driver.version' <<< $cuda_metadata)
CUDA_DRIVER_DISTRIBUTION=$(jq -r '.driver.distribution' <<< $cuda_metadata)
CUDA_SAMPLES_VERSION=$(jq -r '.samples.version' <<< $cuda_metadata)
CUDA_SAMPLES_SHA256=$(jq -r '.samples.sha256' <<< $cuda_metadata)

# Install Cuda
if [[ $DISTRIBUTION == *"ubuntu"* ]]; then
    # Dependency for nvidia driver installation
    apt-get install -y libvulkan1
    # Reference - https://docs.nvidia.com/cuda/cuda-installation-guide-linux/index.html#ubuntu-installation
    wget https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DRIVER_DISTRIBUTION}/x86_64/cuda-keyring_1.1-1_all.deb
    dpkg -i ./cuda-keyring_1.1-1_all.deb
    apt-get update
    apt install -y cuda-toolkit-${CUDA_DRIVER_VERSION//./-}
elif [[ $DISTRIBUTION == almalinux* ]]; then
    dnf config-manager --add-repo https://developer.download.nvidia.com/compute/cuda/repos/${CUDA_DRIVER_DISTRIBUTION}/x86_64/cuda-${CUDA_DRIVER_DISTRIBUTION}.repo
    dnf clean expire-cache
    dnf install -y cuda-toolkit-${CUDA_DRIVER_VERSION//./-}
elif [[ $DISTRIBUTION == "azurelinux3.0" ]]; then    
    path_var="$TOP_DIR/prebuilt"
    version_var="-12.8.1_570.124.06-1.azl3"
    # Install cuda-toolkit dependencies
    tdnf install -y $path_var/nsight-systems-2025.2.1.130_3569061-1.azl3.x86_64.rpm
    tdnf install -y $path_var/nsight-compute-2025.1.1.2_35528883-1.azl3.x86_64.rpm
    # Install cuda-toolkit and sub-packages
    tdnf install -y $path_var/cuda-cccl$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-cudart$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-cudart-devel$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-driver-devel$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-nvml-devel$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-nvrtc$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-nvrtc-devel$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-opencl$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-opencl-devel$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-profiler-api$version_var.x86_64.rpm
    tdnf install -y $path_var/libcublas$version_var.x86_64.rpm
    tdnf install -y $path_var/libcublas-devel$version_var.x86_64.rpm
    tdnf install -y $path_var/libcufft$version_var.x86_64.rpm
    tdnf install -y $path_var/libcufft-devel$version_var.x86_64.rpm
    tdnf install -y $path_var/libcufile$version_var.x86_64.rpm
    tdnf install -y $path_var/libcufile-devel$version_var.x86_64.rpm
    tdnf install -y $path_var/libcurand$version_var.x86_64.rpm
    tdnf install -y $path_var/libcurand-devel$version_var.x86_64.rpm
    tdnf install -y $path_var/libnvfatbin$version_var.x86_64.rpm
    tdnf install -y $path_var/libnvfatbin-devel$version_var.x86_64.rpm
    tdnf install -y $path_var/libnvjitlink$version_var.x86_64.rpm
    tdnf install -y $path_var/libnvjitlink-devel$version_var.x86_64.rpm
    tdnf install -y $path_var/libnvjpeg$version_var.x86_64.rpm
    tdnf install -y $path_var/libnvjpeg-devel$version_var.x86_64.rpm
    tdnf install -y $path_var/libcusparse$version_var.x86_64.rpm
    tdnf install -y $path_var/libcusparse-devel$version_var.x86_64.rpm
    tdnf install -y $path_var/libcusolver$version_var.x86_64.rpm
    tdnf install -y $path_var/libcusolver-devel$version_var.x86_64.rpm
    tdnf install -y $path_var/libnpp$version_var.x86_64.rpm
    tdnf install -y $path_var/libnpp-devel$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-cupti$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-nvdisasm$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-nvprof$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-nvtx$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-nsight$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-nvvp$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-nsight-systems$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-nsight-compute$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-cuobjdump$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-cuxxfilt$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-nvcc$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-nvvm$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-crt$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-nvprune$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-documentation$version_var.x86_64.rpm
    tdnf install -y $path_var/gds-tools$version_var.x86_64.rpm
    tdnf install -y $path_var/cuda-toolkit$version_var.x86_64.rpm
    # Install libnvidia-nscq
    tdnf install -y libnvidia-nscq
fi

echo 'export PATH=$PATH:/usr/local/cuda/bin' | sudo tee /etc/profile.d/cuda.sh > /dev/null
echo 'export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/usr/local/cuda/lib64' | sudo tee -a /etc/profile.d/cuda.sh > /dev/null

# Ensure proper permissions
sudo chmod 644 /etc/profile.d/cuda.sh

write_component_version "CUDA" ${CUDA_DRIVER_VERSION}

# Download CUDA samples
TARBALL="v${CUDA_SAMPLES_VERSION}.tar.gz"
if [[ $DISTRIBUTION == "azurelinux3.0" ]]; then
    cp $TOP_DIR/prebuilt/${TARBALL} .
else
    CUDA_SAMPLES_DOWNLOAD_URL=https://github.com/NVIDIA/cuda-samples/archive/refs/tags/${TARBALL}
    download_and_verify ${CUDA_SAMPLES_DOWNLOAD_URL} ${CUDA_SAMPLES_SHA256}
fi
tar -xvf ${TARBALL}
pushd ./cuda-samples-${CUDA_SAMPLES_VERSION}
mkdir build && cd build
cmake -DCMAKE_CUDA_COMPILER=/usr/local/cuda/bin/nvcc ..
make -j $(nproc)
mv -vT ./Samples /usr/local/cuda-${CUDA_DRIVER_VERSION}/samples # Use the same version as the CUDA toolkit as thats where samples is being moved to
popd

$COMPONENT_DIR/install_gdrcopy.sh "Enable"

# cleanup downloaded files
rm -rf *.run *tar.gz *.rpm
rm -rf -- */