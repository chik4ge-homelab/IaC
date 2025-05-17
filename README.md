# Homelab IaC
## Overview
This repository contains the infrastructure as code (IaC) for my homelab, which is built using Proxmox and Talos Linux.

## Prerequisites
### Terraform
- terraform
### Talhelper
- talhelper
- sops
- age
- jq
- talosctl
- bitwarden-cli

To install all prerequisites / init secrets:
```bash
brew install sops age jq talosctl bitwarden-cli hashicorp/tap/terraform
sh ./init.sh
```

### `./terraform.tfvars` 
```javascript
pve_user        = "user@pam"
pve_password    = "password"
```

### Deploy
```bash
terraform init # optional

terraform apply -target="proxmox_virtual_environment_vm.workers[i]"
talhelper genconfig # after making changes to talconfig.yaml

talhelper gencommand apply # copy and paste the command which is desired to apply

# or

talhelper gencommand upgrade # copy and paste the command which is desired to apply
```
