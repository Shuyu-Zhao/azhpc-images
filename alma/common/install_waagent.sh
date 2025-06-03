#!/bin/bash
set -ex

python3 -m ensurepip --upgrade  # Ensures pip is available
python3 -m pip install --upgrade pip setuptools
python3 -m pip install distro
$COMMON_DIR/install_waagent.sh
systemctl restart waagent
