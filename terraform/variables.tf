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

# OCI edge ingress settings
variable "oci_edge_nodes" {
  description = "Logical edge roles mapped to the existing OCI instance resource keys"
  type = map(object({
    instance_key = string
    backend_port = optional(number)
  }))
  default = {}
}

variable "oci_nlb_listeners" {
  description = "TCP listeners and backend/health-check settings for the OCI Network Load Balancer"
  type = map(object({
    port                  = number
    backend_port          = optional(number, 443)
    protocol              = optional(string, "TCP")
    health_check_protocol = optional(string, "TCP")
    health_check_port     = optional(number, 22)
    health_check_path     = optional(string)
    health_check_interval = optional(number, 10000)
    health_check_timeout  = optional(number, 3000)
    health_check_retries  = optional(number, 3)
    preserve_source       = optional(bool, false)
    proxy_protocol_v2     = optional(bool, false)
  }))
  default = {}

  validation {
    condition = alltrue([
      for listener in values(var.oci_nlb_listeners) : listener.protocol == "TCP"
    ])
    error_message = "oci_nlb_listeners currently supports TCP listeners only."
  }
}

variable "oci_nlb_display_name" {
  description = "Display name for the public OCI Network Load Balancer"
  type        = string
  default     = "edge-nlb"
}

variable "iot_vlan_id" {
  description = "The IoT VLAN ID assigned to selected VM network interfaces"
  type        = number
  default     = null
  nullable    = true

  validation {
    condition     = var.iot_vlan_id == null || (var.iot_vlan_id >= 1 && var.iot_vlan_id <= 4094)
    error_message = "iot_vlan_id must be null or a valid VLAN ID between 1 and 4094."
  }
}

# Talos variables
variable "talos_version" {
  description = "The version of Talos to use"
  type        = string
}

# Fedora CoreOS variables
variable "fedora_coreos_image_url" {
  description = "Pinned Fedora CoreOS Proxmox VE qcow2.xz image URL"
  type        = string
}

variable "fedora_coreos_image_sha256" {
  description = "SHA256 checksum for the decompressed Fedora CoreOS Proxmox VE qcow2 image"
  type        = string
}

variable "switchbot_api_token" {
  description = "SwitchBot Open API token"
  type        = string
  sensitive   = true
}

variable "switchbot_api_secret" {
  description = "SwitchBot Open API secret"
  type        = string
  sensitive   = true
}

variable "switchbot_mqtt_username" {
  description = "MQTT username for the SwitchBot gateway"
  type        = string
  sensitive   = true
}

variable "switchbot_mqtt_password" {
  description = "MQTT password for the SwitchBot gateway"
  type        = string
  sensitive   = true
}

variable "bluetooth_gateways" {
  description = "settings for Bluetooth gateway VMs"
  type = list(
    object({
      active                  = optional(bool, true)
      name                    = string
      vm_id                   = number
      pve_node_name           = string
      ip                      = string
      iot_ip                  = optional(string)
      memory                  = optional(number, 2048)
      cpu_sockets             = optional(number, 1)
      cpu_cores               = optional(number, 1)
      disk_size               = optional(number, 10)
      iot_vlan                = optional(bool, true)
      usb_mapping             = optional(string, "mapping")
      ignition_datastore_id   = optional(string, "local")
      ignition_datastore_path = optional(string, "/var/lib/vz")
      gateway_image           = optional(string)
      gateway_environment     = optional(map(string), {})
    })
  )
  default = []
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
      iot_vlan          = optional(bool, false) # Attach an additional NIC for the IoT VLAN
      usb               = optional(bool, true)  # Enable USB passthrough
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
