terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.93.0"
    }
    butane = {
      source  = "KeisukeYamashita/butane"
      version = "0.1.4"
    }
    oci = {
      source  = "oracle/oci"
      version = "8.29.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://${var.pve_host}/"
  username = var.pve_user
  password = var.pve_password
  insecure = var.pve_tls_insecure
}

# Authentication is supplied through the standard OCI environment variables or
# ~/.oci/config. Keep API keys and private key material outside this repository.
provider "oci" {}
