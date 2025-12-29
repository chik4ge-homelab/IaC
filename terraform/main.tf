locals {
  pve_nodes = distinct(
    concat(
      [for control_node in var.control_planes : control_node.pve_node_name],
      [for worker_node in var.workers : worker_node.pve_node_name]
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

  # image with qemu-guest-agent, other extensions are install when machineconfig is applied
  talos_iso_url       = "https://factory.talos.dev/image/ce4c980550dd2ab1b17bbf2b08801c7eb59418eafe8f279833297925d67c7515/${var.talos_version}/nocloud-amd64.iso"
  talos_iso_file_name = "talos-nocloud-amd64.iso"
}

resource "proxmox_virtual_environment_download_file" "talos_cloud_image" {
  node_name           = "host01"
  content_type        = "iso"
  datastore_id        = "truenas-nfs"
  url                 = local.talos_iso_url
  file_name           = local.talos_iso_file_name
  overwrite_unmanaged = true
}

resource "proxmox_virtual_environment_vm" "control_planes" {
  for_each = local.control_planes_by_name

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

  # OpenEBS dedicated disk
  disk {
    datastore_id = "local-lvm"
    file_format  = "raw"
    interface    = "scsi2"
    iothread     = true
    ssd          = true
    discard      = "on"
    size         = each.value.openebs_disk_size
  }

  agent {
    enabled = true
    trim    = true
  }

  network_device {
    bridge  = "vmbr0"
    vlan_id = var.network_vlan_id
  }

  dynamic "usb" {
    for_each = each.value.usb ? [1] : []
    content {
      mapping = "mapping"
      usb3    = true
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
