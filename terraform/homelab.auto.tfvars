# Non-secret values describing this homelab. Secrets continue to be supplied by fnox.
pve_tls_insecure = true
pve_host         = "192.168.0.150:8006"

network_mask    = "24"
network_gateway = "192.168.1.1"
network_vlan_id = 20

talos_version = "v1.13.0" # renovate: datasource=github-releases packageName=siderolabs/talos

control_planes = [
  {
    name          = "k8s-cp-argon"
    vm_id         = 101
    pve_node_name = "host01"
    ip            = "192.168.1.101"
    cpu_cores     = 1
    memory        = 6 * 1024
  },
  {
    name          = "k8s-cp-boron"
    vm_id         = 102
    pve_node_name = "host02"
    ip            = "192.168.1.102"
    cpu_cores     = 1
    memory        = 6 * 1024
  },
  {
    name          = "k8s-cp-carbon"
    vm_id         = 103
    pve_node_name = "host04"
    ip            = "192.168.1.103"
    memory        = 6 * 1024
  },
]

workers = [
  {
    name              = "k8s-w-anemone"
    vm_id             = 201
    pve_node_name     = "host01"
    ip                = "192.168.1.201"
    cpu_cores         = 3
    memory            = 8 * 1024
    disk_size         = 100
    openebs_disk_size = 200
  },
  {
    name              = "k8s-w-blossom"
    vm_id             = 202
    pve_node_name     = "host04"
    ip                = "192.168.1.202"
    memory            = 24 * 1024
    cpu_cores         = 12
    disk_size         = 100
    openebs_disk_size = 200
    usb               = false
  },
  {
    name              = "k8s-w-clover"
    vm_id             = 203
    pve_node_name     = "host02"
    ip                = "192.168.1.203"
    cpu_cores         = 15
    memory            = 22 * 1024
    disk_size         = 100
    openebs_disk_size = 200
  },
  {
    active        = false
    name          = "k8s-w-daisy"
    vm_id         = 204
    pve_node_name = "host02"
    ip            = "192.168.1.204"
    memory        = 13 * 1024
    disk_size     = 256
  },
  {
    name              = "k8s-w-edelweiss"
    vm_id             = 205
    pve_node_name     = "host03"
    ip                = "192.168.1.205"
    memory            = 18 * 1024
    cpu_cores         = 12
    disk_size         = 100
    openebs_disk_size = 200
    usb               = false
    pci_mappings = [
      {
        mapping = "RTX3060Ti"
        pcie    = true
      }
    ]
  },
  {
    name          = "k8s-w-freesia"
    vm_id         = 206
    pve_node_name = "host05"
    ip            = "192.168.1.206"
    memory        = 28 * 1024
    cpu_cores     = 12
    disk_size     = 100
    usb           = false
  },
]

usb_devices = [
  {
    id      = "8087:0026"
    node    = "host01"
    comment = "Intel Corp. AX201 Bluetooth"
  },
  {
    id      = "0bda:c820"
    node    = "host02"
    comment = "Realtek Semiconductor Corp. 802.11ac NIC"
  }
]

pci_devices = [
  {
    name = "RTX3060Ti"
    map = [{
      id           = "10de:2489"
      iommu_group  = 15
      node         = "host03"
      path         = "0000:01:00"
      subsystem_id = "1462:c972"
    }]
  }
]
