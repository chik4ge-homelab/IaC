locals {
  pve_nodes = distinct(
    concat(
      [for control_node in var.control_planes : control_node.pve_node_name],
      [for worker_node in var.workers : worker_node.pve_node_name],
      [for bluetooth_gateway in var.bluetooth_gateways : bluetooth_gateway.pve_node_name]
    )
  )

  # Map to associate node names with the corresponding talos_cloud_image index
  node_to_image_index = {
    for idx, node in local.pve_nodes : node => idx
  }

  control_planes_by_name = {
    for control_plane in var.control_planes : control_plane.name => control_plane if control_plane.active
  }

  workers_by_name = {
    for worker in var.workers : worker.name => worker if worker.active
  }

  bluetooth_gateways_by_name = {
    for bluetooth_gateway in var.bluetooth_gateways : bluetooth_gateway.name => bluetooth_gateway if bluetooth_gateway.active
  }

  # image with qemu-guest-agent, other extensions are install when machineconfig is applied
  talos_iso_url       = "https://factory.talos.dev/image/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515/${var.talos_version}/nocloud-amd64.iso"
  talos_iso_file_name = "talos-nocloud-amd64.iso"

  bluetooth_gateway_butane = {
    for name, gateway in local.bluetooth_gateways_by_name : name => templatefile("${path.module}/templates/bluetooth-gateway.bu.tftpl", {
      name            = gateway.name
      ip              = gateway.ip
      iot_ip          = gateway.iot_ip
      iot_vlan        = gateway.iot_vlan
      network_mask    = var.network_mask
      network_gateway = var.network_gateway
      ssh_authorized_keys = [
        trimspace(file(pathexpand("~/.ssh/id_ed25519.pub")))
      ]
      gateway_image = gateway.gateway_image
      gateway_environment = merge(gateway.gateway_environment, {
        MQTT_HOST            = lookup(gateway.gateway_environment, "MQTT_HOST", "127.0.0.1")
        MQTT_PORT            = lookup(gateway.gateway_environment, "MQTT_PORT", "1883")
        SWITCHBOT_API_TOKEN  = var.switchbot_api_token
        SWITCHBOT_API_SECRET = var.switchbot_api_secret
        MQTT_USERNAME        = var.switchbot_mqtt_username
        MQTT_PASSWORD        = var.switchbot_mqtt_password
      })
    })
  }
}

resource "proxmox_virtual_environment_download_file" "talos_cloud_image" {
  node_name           = "host01"
  content_type        = "iso"
  datastore_id        = "truenas-nfs"
  url                 = local.talos_iso_url
  file_name           = local.talos_iso_file_name
  overwrite_unmanaged = true
}

resource "proxmox_virtual_environment_file" "fedora_coreos_image" {
  node_name    = "host01"
  content_type = "iso"
  datastore_id = "truenas-nfs"
  overwrite    = true

  source_file {
    path      = "${path.module}/.cache/fedora-coreos-proxmoxve.x86_64.qcow2"
    file_name = "fedora-coreos-proxmoxve.x86_64.qcow2.img"
    checksum  = var.fedora_coreos_image_sha256
  }
}

data "butane_config" "bluetooth_gateway_ignition" {
  for_each = local.bluetooth_gateways_by_name

  content = local.bluetooth_gateway_butane[each.key]
  strict  = true
}

resource "proxmox_virtual_environment_file" "bluetooth_gateway_ignition" {
  for_each = local.bluetooth_gateways_by_name

  content_type = "snippets"
  datastore_id = each.value.ignition_datastore_id
  node_name    = each.value.pve_node_name
  overwrite    = true

  source_raw {
    data      = sensitive(data.butane_config.bluetooth_gateway_ignition[each.key].ignition)
    file_name = "${each.value.name}.ign"
  }
}

resource "terraform_data" "bluetooth_gateway_ignition_sha256" {
  for_each = local.bluetooth_gateways_by_name

  # Keep the delivery mechanism in the replacement trigger. Fedora CoreOS
  # reads a valid Ignition config from Proxmox user-data, while Proxmox also
  # generates a cloud-config user-data file when this is left unset.
  input = sha256("user-data:${data.butane_config.bluetooth_gateway_ignition[each.key].ignition}")
}

resource "proxmox_virtual_environment_vm" "control_planes" {
  for_each = local.control_planes_by_name

  lifecycle {
    ignore_changes = [
      disk[0].file_id,
      tpm_state,
    ]
  }

  name        = each.value.name
  description = "Managed by Terraform"
  tags        = sort(["kubernetes", "k8s-control"])

  bios            = "ovmf"
  machine         = "q35"
  stop_on_destroy = false
  scsi_hardware   = "virtio-scsi-single"
  operating_system {
    type = "l26"
  }

  node_name = each.value.pve_node_name
  vm_id     = each.value.vm_id

  cpu {
    sockets = each.value.cpu_sockets
    cores   = each.value.cpu_cores
    type    = "x86-64-v2-AES"
    units   = 1024
  }

  memory {
    dedicated = each.value.memory
  }

  tpm_state {
    version = "v2.0"
  }

  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "4m"
  }

  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi0"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = each.value.disk_size
    file_id      = proxmox_virtual_environment_download_file.talos_cloud_image.id
  }

  agent {
    enabled = true
    trim    = true
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = var.network_vlan_id
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.network_mask}"
        gateway = var.network_gateway
      }
    }
    dns {
      servers = [
        # "100.100.100.100",
        "8.8.8.8",
        "8.8.4.4"
      ]
    }
  }
}

resource "proxmox_virtual_environment_vm" "workers" {
  for_each = local.workers_by_name

  lifecycle {
    ignore_changes = [
      disk[0].file_id,
      tpm_state,
    ]

    precondition {
      condition     = !each.value.iot_vlan || var.iot_vlan_id != null
      error_message = "iot_vlan_id must be set when a worker has iot_vlan enabled."
    }
  }

  name        = each.value.name
  description = "Managed by Terraform"
  tags        = sort(["kubernetes", "k8s-worker"])

  bios            = "ovmf"
  machine         = "q35"
  stop_on_destroy = false
  scsi_hardware   = "virtio-scsi-single"
  started         = each.value.active
  on_boot         = each.value.active
  operating_system {
    type = "l26"
  }

  node_name = each.value.pve_node_name
  vm_id     = each.value.vm_id

  cpu {
    sockets = each.value.cpu_sockets
    cores   = each.value.cpu_cores
    type    = "x86-64-v2-AES"
    units   = 1024
  }

  memory {
    dedicated = each.value.memory
  }

  tpm_state {
    version = "v2.0"
  }

  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "4m"
  }

  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi0"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = 10 # 10GB
    file_id      = proxmox_virtual_environment_download_file.talos_cloud_image.id
  }

  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi1"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = each.value.disk_size
  }

  dynamic "disk" {
    for_each = each.value.openebs_disk_size == null ? [] : [each.value.openebs_disk_size]

    content {
      datastore_id = "local-lvm"
      file_format  = "raw"
      interface    = "scsi2"
      iothread     = true
      ssd          = true
      discard      = "on"
      size         = disk.value
    }
  }

  agent {
    enabled = true
    trim    = true
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = var.network_vlan_id
  }

  dynamic "network_device" {
    for_each = each.value.iot_vlan ? [1] : []
    content {
      bridge  = "vmbr0"
      vlan_id = var.iot_vlan_id
    }
  }

  dynamic "usb" {
    for_each = each.value.usb ? [1] : []
    content {
      mapping = "mapping"
      usb3    = true
    }
  }

  dynamic "hostpci" {
    for_each = try(each.value.pci_mappings, [])
    content {
      device  = "hostpci${hostpci.key}"
      mapping = hostpci.value.mapping
      pcie    = hostpci.value.pcie
      rombar  = hostpci.value.rombar
      xvga    = hostpci.value.xvga
    }
  }

  initialization {
    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.network_mask}"
        gateway = var.network_gateway
      }
    }
    dns {
      servers = [
        # "100.100.100.100",
        "8.8.8.8",
        "8.8.4.4"
      ]
    }
  }
}

resource "proxmox_virtual_environment_vm" "bluetooth_gateways" {
  for_each = local.bluetooth_gateways_by_name

  lifecycle {
    ignore_changes = [
      disk[0].file_id,
      tpm_state,
    ]

    replace_triggered_by = [
      terraform_data.bluetooth_gateway_ignition_sha256[each.key],
    ]

    precondition {
      condition     = !each.value.iot_vlan || var.iot_vlan_id != null
      error_message = "iot_vlan_id must be set when a Bluetooth gateway has iot_vlan enabled."
    }

    precondition {
      condition     = !each.value.iot_vlan || each.value.iot_ip != null
      error_message = "iot_ip must be set when a Bluetooth gateway has iot_vlan enabled."
    }
  }

  name        = each.value.name
  description = "Managed by Terraform"
  tags        = sort(["bluetooth", "home-assistant"])

  bios            = "ovmf"
  machine         = "q35"
  stop_on_destroy = true
  scsi_hardware   = "virtio-scsi-pci"
  started         = each.value.active
  on_boot         = each.value.active
  operating_system {
    type = "l26"
  }

  node_name = each.value.pve_node_name
  vm_id     = each.value.vm_id

  cpu {
    sockets = each.value.cpu_sockets
    cores   = each.value.cpu_cores
    type    = "x86-64-v2-AES"
    units   = 1024
  }

  memory {
    dedicated = each.value.memory
  }

  tpm_state {
    version = "v2.0"
  }

  efi_disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    type         = "4m"
  }

  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi0"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = each.value.disk_size
    file_id      = proxmox_virtual_environment_file.fedora_coreos_image.id
  }

  initialization {
    datastore_id      = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.bluetooth_gateway_ignition[each.key].id

    ip_config {
      ipv4 {
        address = "${each.value.ip}/${var.network_mask}"
        gateway = var.network_gateway
      }
    }

    dns {
      servers = [
        "8.8.8.8",
        "8.8.4.4"
      ]
    }
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = var.network_vlan_id
  }

  dynamic "network_device" {
    for_each = each.value.iot_vlan ? [1] : []
    content {
      bridge  = "vmbr0"
      vlan_id = var.iot_vlan_id
    }
  }

  usb {
    mapping = each.value.usb_mapping
    usb3    = true
  }

  serial_device {
    device = "socket"
  }

  vga {
    type = "serial0"
  }

  depends_on = [
    proxmox_virtual_environment_file.bluetooth_gateway_ignition,
  ]
}

resource "proxmox_virtual_environment_hardware_mapping_usb" "usb_mapping" {
  comment = "Managed by terraform"
  name    = "mapping"
  map = [
    for device in var.usb_devices :
    {
      id      = device.id
      node    = device.node
      comment = device.comment
    }
  ]
}

resource "proxmox_virtual_environment_hardware_mapping_pci" "pci_mappings" {
  count   = length(var.pci_devices)
  comment = "Managed by terraform"
  name    = var.pci_devices[count.index].name
  map = [
    for device in var.pci_devices[count.index].map :
    {
      id           = device.id
      node         = device.node
      path         = device.path
      iommu_group  = device.iommu_group
      subsystem_id = device.subsystem_id
    }
  ]
}
