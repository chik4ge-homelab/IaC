# Non-secret values describing this homelab. Secrets continue to be supplied by fnox.
pve_tls_insecure = true
pve_host         = "192.168.0.150:8006"

network_mask    = "24"
network_gateway = "192.168.1.1"
network_vlan_id = 20
iot_vlan_id     = 30

oci_edge_nodes = {
  # Keep the imported instance resource keys stable; these are logical roles.
  edge03 = {
    instance_key = "oci03"
  }
  edge04 = {
    instance_key = "oci04"
  }
}

oci_nlb_listeners = {
  tcp_443 = {
    port                  = 443
    backend_port          = 443
    health_check_protocol = "TCP"
    # Existing VMs expose SSH; switch to HTTP/8080 /ready once edge-agent does.
    health_check_port     = 443
    health_check_interval = 10000
    health_check_timeout  = 3000
    health_check_retries  = 3
    preserve_source       = true
    proxy_protocol_v2     = false
  }
  tcp_25565 = {
    port                  = 25565
    backend_port          = 25565
    health_check_protocol = "TCP"
    health_check_port     = 25565
    health_check_interval = 10000
    health_check_timeout  = 3000
    health_check_retries  = 3
    preserve_source       = true
    proxy_protocol_v2     = false
  }
}

talos_version = "v1.13.0" # renovate: datasource=github-releases packageName=siderolabs/talos

fedora_coreos_image_url    = "https://builds.coreos.fedoraproject.org/prod/streams/stable/builds/44.20260607.3.1/x86_64/fedora-coreos-44.20260607.3.1-proxmoxve.x86_64.qcow2.xz"
fedora_coreos_image_sha256 = "940cfaec230e743f7d781fb036a117c753d06ffe30ff8cef3b991807aa73b279"

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
    cpu_cores         = 2
    memory            = 7 * 1024
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
    iot_vlan          = true
    usb               = true
  },
  {
    name              = "k8s-w-clover"
    vm_id             = 203
    pve_node_name     = "host02"
    ip                = "192.168.1.203"
    cpu_cores         = 15
    memory            = 32 * 1024
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
    iot_vlan      = true
    usb           = true
  },
]

bluetooth_gateways = [
  {
    name          = "bt-proxy-argon"
    vm_id         = 207
    pve_node_name = "host01"
    ip            = "192.168.1.207"
    iot_ip        = "192.168.3.207"
    cpu_cores     = 1
    memory        = 2 * 1024
    disk_size     = 10
    iot_vlan      = true
    gateway_image = "ghcr.io/chik4ge/switchbot-mqtt-gateway@sha256:3584751ae5f6d9830a475a83958a1f6d902e2f08cfce67700dfa41b63612d6f2"
  },
]

usb_devices = [
  {
    id      = "8087:0026"
    node    = "host01"
    comment = "Intel Corp. AX201 Bluetooth"
  },
  {
    id      = "0e8d:c616"
    node    = "host04"
    comment = "MediaTek Inc. Wireless_Device Bluetooth"
  },
  {
    id      = "0e8d:c616"
    node    = "host05"
    comment = "MediaTek Inc. Wireless_Device Bluetooth"
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
