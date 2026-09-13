locals {
  oci_compartment_id      = "ocid1.tenancy.oc1..aaaaaaaaaqlhtjkfznw2j7zozitiifywlpmd34op5cxtubbtioxof46o2mva"
  oci_availability_domain = "CtXY:AP-OSAKA-1-AD-1"
  oci_subnet_id           = "ocid1.subnet.oc1.ap-osaka-1.aaaaaaaawk4optuzzidha4qroipajrti3dw6lcou2feygwnnccbcvqi6jwca"
  oci_image_id            = "ocid1.image.oc1.ap-osaka-1.aaaaaaaaglaxxdyc7fwf77e4lq26h2nhik52d2bmxjuiqe5mzndw3zpmj4hq"

  oci_edge_instances = {
    oci03 = {
      instance_id = "ocid1.instance.oc1.ap-osaka-1.anvwsljrdjlhumicryukklda7ol5oc2ucn6bnhl2wpw7t7rpxca2f7gti4ja"
      private_ip  = "10.0.0.242"
      ssh_authorized_keys = trimspace(<<-EOT
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCsC1fSLtpv/I4ea5q1GogtoWHN9qstu0wvvN50f/iXt9COAG2H9ciC7RCFVWdFQlk4q/t7qZZ1jzLpuiBw7bUvTa2kuiLCcYnjPAEjOpzraZHp0T+IEcv08YcUQUoZ2PK8yUgXmYMIhP7CIYbtadr3BVMWDG7k7H83SzCUQxLROemwhkMN/7ndCb7ip/4X8FRWGkuylzFvmX2epMhhxYfvEyXGQ+OLESjhxqw6GEabyu/U3K8pPnbrx7OGXqjO6HrXG2yRsHNAWZ/YRr1gzJo+LRMBIZfmXfmhUBtHacyj0sn9udL6lhQnsQ12lvYQkWHEbxRMpA6QLBZqswls9Arp ssh-key-2025-09-16
      EOT
      )
    }
    oci04 = {
      instance_id = "ocid1.instance.oc1.ap-osaka-1.anvwsljrdjlhumicbpo7rss25kwztyvql2e2lv74wgrrrubbl6bm2bsrdnka"
      private_ip  = "10.0.0.116"
      ssh_authorized_keys = trimspace(<<-EOT
        ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCx3PnnedgCgG9H/6LSM2TYL159Nj63ObBzydF8OLkf0Eu9IIfd6TBUwV0tldYKHqvF6YoIKwuC6Z/xCCtTfrHC7dYEUad4S+xik7TZ3RkwnGlW+Zy+18T1w5B7Jh+B+CWQlVYLOeSG1dDxooSpaF1wlER2uWT8/ltyMHH33nV2oaYXxmIXe/rwhm9K2v7X1xWk0RP4Ahk4iqRRw2RWhgpdICbCXXn7HS+k+9iqoox08dEWxtkePx7zQZeQn6Y6A4gMw9Gc0L3puALeLxptMo6kmSXi/MQhGcXkRtg/KASF02SAO0P6NFFQiuqKfPNaPMLYgNdjFFEWFAYKxgm5NExR ssh-key-2025-09-18
      EOT
      )
    }
  }
}

resource "oci_core_instance" "edge" {
  for_each = local.oci_edge_instances

  availability_domain = local.oci_availability_domain
  compartment_id      = local.oci_compartment_id
  display_name        = each.key
  fault_domain        = "FAULT-DOMAIN-3"
  shape               = "VM.Standard.A1.Flex"
  state               = "RUNNING"

  metadata = {
    ssh_authorized_keys = each.value.ssh_authorized_keys
  }

  lifecycle {
    prevent_destroy = true
  }

  agent_config {
    are_all_plugins_disabled = false
    is_management_disabled   = false
    is_monitoring_disabled   = false

    plugins_config {
      desired_state = "DISABLED"
      name          = "Vulnerability Scanning"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Management Agent"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Custom Logs Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute RDMA GPU Monitoring"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Compute Instance Monitoring"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Auto-Configuration"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Compute HPC RDMA Authentication"
    }
    plugins_config {
      desired_state = "ENABLED"
      name          = "Cloud Guard Workload Protection"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Block Volume Management"
    }
    plugins_config {
      desired_state = "DISABLED"
      name          = "Bastion"
    }
  }

  availability_config {
    is_live_migration_preferred = false
    recovery_action             = "RESTORE_INSTANCE"
  }

  create_vnic_details {
    assign_ipv6ip             = false
    assign_private_dns_record = false
    assign_public_ip          = "true"
    display_name              = each.key
    hostname_label            = each.key
    private_ip                = each.value.private_ip
    skip_source_dest_check    = false
    subnet_id                 = local.oci_subnet_id
  }

  instance_options {
    are_legacy_imds_endpoints_disabled = false
  }

  launch_options {
    boot_volume_type                    = "PARAVIRTUALIZED"
    firmware                            = "UEFI_64"
    is_consistent_volume_naming_enabled = true
    is_pv_encryption_in_transit_enabled = true
    network_type                        = "PARAVIRTUALIZED"
    remote_data_volume_type             = "PARAVIRTUALIZED"
  }

  shape_config {
    memory_in_gbs = 6
    ocpus         = 1
  }

  source_details {
    boot_volume_size_in_gbs         = "47"
    boot_volume_vpus_per_gb         = "10"
    is_preserve_boot_volume_enabled = false
    source_id                       = local.oci_image_id
    source_type                     = "image"
  }
}
