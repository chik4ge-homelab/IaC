# Proxmox VE settings
variable "pve_user" {
  description = "The username for the proxmox user"
  type        = string
  sensitive   = false
}
variable "pve_password" {
  description = "The password for the proxmox user"
  type        = string
  sensitive   = true
}
variable "pve_tls_insecure" {
  description = "Set to true to ignore certificate errors"
  type        = bool
}
variable "pve_host" {
  description = "The hostname or IP of the proxmox server"
  type        = string
}

# network variables
variable "network_mask" {
  description = "The subnet mask for the VMs"
  type        = string
}
variable "network_gateway" {
  description = "The network gateway for the VMs"
  type        = string
}

variable "network_vlan_id" {
  description = "The VLAN ID assigned to VM network interfaces"
  type        = number
}

# Talos variables
variable "talos_version" {
  description = "The version of Talos to use"
  type        = string
}

variable "control_planes" {
  description = "settings for k8s control planes"
  type = list(
    object({
      active        = optional(bool, true) # Enable or disable the control plane node
      name          = string
      vm_id         = number
      pve_node_name = string
      ip            = string
      memory        = optional(number, 6 * 1024) # 6GB
      cpu_sockets   = optional(number, 1)
      cpu_cores     = optional(number, 4)
      disk_size     = optional(number, 20) # 20GB
    })
  )
}

variable "workers" {
  description = "settings for k8s worker nodes"
  type = list(
    object({
      active            = optional(bool, true) # Enable or disable the worker node
      name              = string
      vm_id             = number
      pve_node_name     = string
      ip                = string
      memory            = optional(number, 10 * 1024) # 10GB (per-node override below)
      cpu_sockets       = optional(number, 1)
      cpu_cores         = optional(number, 4)
      disk_size         = optional(number, 130) # 130GB
      openebs_disk_size = optional(number)
      usb               = optional(bool, true) # Enable USB passthrough
      pci_mappings = optional(
        list(
          object({
            mapping = string
            pcie    = optional(bool, false)
            rombar  = optional(bool, true)
            xvga    = optional(bool, false)
          })
        ),
        []
      ) # PCI passthrough mappings
    })
  )
}

variable "usb_devices" {
  description = "List of USB devices for the VMs"
  type = list(
    object({
      id      = string
      node    = string
      comment = string
    })
  )
}

variable "pci_devices" {
  description = "List of PCI devices for the VMs"
  type = list(
    object({
      name = string
      map = list(
        object({
          id           = string
          path         = string
          node         = string
          iommu_group  = optional(number)
          subsystem_id = optional(string)
        })
      )
    })
  )
}
