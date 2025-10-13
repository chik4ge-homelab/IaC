terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.85.0"
    }
  }
}

provider "proxmox" {
  endpoint = "https://${var.pve_host}/"
  username = var.pve_user
  password = var.pve_password
  insecure = var.pve_tls_insecure
}
