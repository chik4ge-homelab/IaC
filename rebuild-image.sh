#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

pushd terraform > /dev/null
terraform apply -auto-approve --target="proxmox_virtual_environment_download_file.talos_cloud_image"
popd > /dev/null
