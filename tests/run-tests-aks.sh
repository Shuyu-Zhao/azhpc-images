#!/bin/bash

# ------------------------------------------------------------------------------
# Script Name : example.sh
# Description : This script performs initialization and testing for a specified platform.
# Usage       : ./example.sh <platform> [debug_flag]
#
# Sample Usage:
#   ./run-tests.sh 
#   ./example.sh NVIDIA -d
#   ./example.sh AMD -d

# Arguments   :
#   $1 - Platform type (optional):
#        "AMD" or "NVIDIA"
#        "NVIDIA" when omitted
#
#   $2 - Debug mode flag (optional):
#        Specify "-d" to enable debug mode. 
#        In debug mode, the script continues running even if a single test fails.
#        If omitted or not "-d", the script runs in normal mode (strict failure handling).


# Verify common component installations accross all distros
function verify_common_components {
    verify_package_updates;
    verify_ofed_installation;
    verify_ib_device_status;
    verify_ipoib_status;
    verify_nvidia_fabricmanager_service;
    # verify_cuda_installation;
    # verify_gdrcopy_installation;
    # verify_dcgm_installation;
}

function initiate_test_suite {
    # Run the common component tests
    verify_common_components
}

function set_test_matrix {
    gpu_platform="NVIDIA"
    if [[ "$#" -gt 0 ]]; then
       GPU_PLAT=$1
       if [[ ${GPU_PLAT} == "AMD" ]]; then
          gpu_platform="AMD"
       elif [[ ${GPU_PLAT} != "NVIDIA" ]]; then
          echo "${GPU_PLAT} is not a valid GPU platform"
          exit 1

       fi
    fi
    export distro=$(. /etc/os-release;echo $ID$VERSION_ID)
    test_matrix_file=$(jq -r . $HPC_ENV/test/test-matrix_${gpu_platform}.json)
    export TEST_MATRIX=$(jq -r '."'"$distro"'" // empty' <<< $test_matrix_file)

    if [[ -z "$TEST_MATRIX" ]]; then
        echo "*****No test matrix found for distribution $distro!*****"
        exit 1
    fi
}

function set_sku_configuration {
    local metadata_endpoint="http://169.254.169.254/metadata/instance?api-version=2019-06-04"
    local vm_size=$(curl -H Metadata:true $metadata_endpoint | jq -r ".compute.vmSize")
    export VMSIZE=$(echo "$vm_size" | awk '{print tolower($0)}')
}

# Function to set component versions from JSON file
function set_component_versions {
    local component_versions_file=$HPC_ENV/component_versions.txt
    # read and set the component versions
    local component_versions=$(cat ${component_versions_file} | jq -r 'to_entries | .[] | "VERSION_\(.key)=\(.value)"')
    echo "Component versions: $component_versions"

    # Set the component versions based on the keys and values
    while read -r component; do
        if [[ ! -z "$component" ]]; then
            eval "export $component" # Associates component name as variable and version as value
        fi
    done <<< "$component_versions"
}

# Load profile
. /etc/profile
# Set HPC environment
HPC_ENV=/opt/azurehpc
# Set test definitions
. $HPC_ENV/test/test-definitions.sh
# Set module files directory
. /etc/os-release
# Set component versions
set_component_versions
# Set current SKU
set_sku_configuration
# Set test matrix
set_test_matrix $1
# Initiate test suite
if [[ -n "$2" && "$2" == "-d" ]]; then export HPC_DEBUG=$2; else export HPC_DEBUG=; fi 
initiate_test_suite

echo "ALL OK!"
