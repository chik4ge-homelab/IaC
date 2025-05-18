# Homelab IaC
## Overview
This repository contains the infrastructure as code (IaC) for my homelab, which is built using Proxmox and Talos Linux.

### Talos etcd Disaster Recovery (talos-backup + age)

etcd snapshots are backed up using [siderolabs/talos-backup](https://github.com/siderolabs/talos-backup).
The backup CronJob is managed in the separate repository: `homelab-application`.
Please refer to that repository for CronJob configuration and management.

1. Download the encrypted snapshot from S3 or other storage, and decrypt it with your age private key:
   ```sh
   age -d -i <private key file> <encrypted snapshot> > db.snapshot
   ```
2. Set your control plane node(s) to "Preparing" state, then recover etcd using the official Talos procedure:
   ```sh
   talosctl -n <IP> bootstrap --recover-from=./db.snapshot
   ```
For details, see: [Talos Official Disaster Recovery](https://www.talos.dev/v1.10/advanced/disaster-recovery/)

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
