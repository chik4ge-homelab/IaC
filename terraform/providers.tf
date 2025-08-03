terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.81.0"
    }

    # talos = {
    #   source  = "siderolabs/talos"
    #   version = "0.7.1"
    # }

    # kubernetes = {
    #   source  = "hashicorp/kubernetes"
    #   version = "2.35.1"
    # }

    # helm = {
    #   source  = "hashicorp/helm"
    #   version = "3.0.0-pre1"
    # }

    # argocd = {
    #   source  = "dcoppa/argocd"
    #   version = "6.1.0-46"
    # }
  }
}

# locals {
#   kubernetes_config = {
#     host                   = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host
#     client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
#     client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
#     cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
#   }
# }

provider "proxmox" {
  endpoint = "https://${var.pve_host}/"
  username = var.pve_user
  password = var.pve_password
  insecure = var.pve_tls_insecure
}

# provider "kubernetes" {
#   host = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host

#   client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
#   client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
#   cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
# }

# provider "helm" {
#   kubernetes = {
#     host = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host

#     client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
#     client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
#     cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
#   }
# }

# provider "argocd" {
#   port_forward = true
#   username     = "admin"
#   password     = data.kubernetes_secret.argocd-initial-admin-secret.data["password"]
#   kubernetes {
#     host = talos_cluster_kubeconfig.this.kubernetes_client_configuration.host

#     client_certificate     = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_certificate)
#     client_key             = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.client_key)
#     cluster_ca_certificate = base64decode(talos_cluster_kubeconfig.this.kubernetes_client_configuration.ca_certificate)
#   }
# }
