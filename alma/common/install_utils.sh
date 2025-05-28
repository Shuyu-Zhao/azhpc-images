#!/bin/bash
set -ex

source ${COMMON_DIR}/utilities.sh
OS_MAJOR_VERSION="$1"

# Install Python 3
if [[ $OS_MAJOR_VERSION == "9" ]]; then 
    yum install -y python3.12
    ln -fs /usr/bin/python3.12 /usr/bin/python3
elif  [[ $OS_MAJOR_VERSION == "8" ]]; then
    yum install -y python3.8
    ln -fs /usr/bin/python3.8 /usr/bin/python3
fi

# install pssh
pssh_metadata=$(get_component_config "pssh")
pssh_version=$(jq -r '.version' <<< $pssh_metadata)
pssh_sha256=$(jq -r '.sha256' <<< $pssh_metadata)
pssh_download_url="https://dl.fedoraproject.org/pub/epel/$OS_MAJOR_VERSION/Everything/aarch64/Packages/p/pssh-$pssh_version.el$OS_MAJOR_VERSION.noarch.rpm"
$COMMON_DIR/download_and_verify.sh $pssh_download_url $pssh_sha256

yum install -y  pssh-$pssh_version.el$OS_MAJOR_VERSION.noarch.rpm
rm -f pssh-$pssh_version.el$OS_MAJOR_VERSION.noarch.rpm

# Install pre-reqs and development tools
yum groupinstall -y "Development Tools"
yum install -y numactl \
    numactl-devel \
    libxml2-devel \
    byacc \
    python3-devel \
    python3-setuptools \
    gtk2 \
    atk \
    cairo \
    tcl \
    tk \
    m4 \
    glibc-devel \
    libudev-devel \
    binutils \
    binutils-devel \
    selinux-policy-devel \
    nfs-utils \
    fuse-libs \
    libpciaccess \
    cmake \
    libnl3-devel \
    libsecret \
    rpm-build \
    make \
    check \
    check-devel \
    lsof \
    kernel-rpm-macros \
    tcsh \
    gcc-gfortran \
    perl

# Install environment-modules 5.3.0
wget https://repo.almalinux.org/vault/9.4/BaseOS/x86_64/os/Packages/environment-modules-5.3.0-1.el9.x86_64.rpm
yum install -y environment-modules-5.3.0-1.el9.x86_64.rpm
rm -f environment-modules-5.3.0-1.el9.x86_64.rpm

## Disable kernel updates
echo "exclude=kernel*" | tee -a /etc/dnf/dnf.conf

# Disable dependencies on kernel core
sed -i "$ s/$/ shim*/" /etc/dnf/dnf.conf
sed -i "$ s/$/ grub2*/" /etc/dnf/dnf.conf

## Install dkms from the EPEL repository
DKMS_BASE_URL="https://dl.fedoraproject.org/pub/epel/${OS_MAJOR_VERSION}/Everything/x86_64/Packages/d"
# Get latest matching dkms RPM
DKMS_RPM=$(curl -s ${DKMS_BASE_URL}/ | grep -oP 'dkms-[\d\.\-]+\.el'"$OS_MAJOR_VERSION"'\.noarch\.rpm' | sort -V | tail -n 1)
wget "${DKMS_BASE_URL}/${DKMS_RPM}"
yum localinstall "${DKMS_RPM}" -y

## Install subunit and subunit-devel from EPEL repository
wget -r --no-parent -A "subunit-*.el$OS_MAJOR_VERSION.x86_64.rpm" https://dl.fedoraproject.org/pub/epel/$OS_MAJOR_VERSION/Everything/x86_64/Packages/s/
yum localinstall ./dl.fedoraproject.org/pub/epel/$OS_MAJOR_VERSION/Everything/x86_64/Packages/s/subunit-[0-9].*.el$OS_MAJOR_VERSION.x86_64.rpm -y
yum localinstall ./dl.fedoraproject.org/pub/epel/$OS_MAJOR_VERSION/Everything/x86_64/Packages/s/subunit-devel-[0-9].*.el$OS_MAJOR_VERSION.x86_64.rpm -y

# Remove rpm files
rm -rf ./dl.fedoraproject.org/
rm -rf ./repo.almalinux.org/

# Install azcopy tool
$COMMON_DIR/install_azcopy.sh

# copy kvp client file
$COMMON_DIR/copy_kvp_client.sh

# copy torset tool
$COMMON_DIR/copy_torset_tool.sh
