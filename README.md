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
- [mise](https://mise.jdx.dev/)
- [1Password CLI](https://developer.1password.com/docs/cli/)

The tools used by this repository are defined in `mise.toml`.

```sh
mise install
```

## Terraform

Terraform commands run through the `tf` mise task. It loads Proxmox credentials
and the Cloudflare R2 backend credentials from 1Password using
`terraform/.env`.

Terraform state is stored in the Cloudflare R2 `terraform-state` bucket at
`terraform/proxmox/terraform.tfstate`.

Initialize the backend after cloning the repository:

```sh
mise run tf init
```

Run `mise run tf init -reconfigure` after changing the backend configuration.

Plan and apply changes:

```sh
mise run tf plan
mise run tf apply
```

## Talhelper

Run Talhelper from its configuration directory. SOPS retrieves the age
identity from 1Password through the environment configured in `mise.toml` and
decrypts the committed `talenv.sops.yaml` and `talsecret.sops.yaml` files as
needed.

```sh
cd talhelper
talhelper genconfig
talhelper gencommand apply
talhelper gencommand upgrade
```
