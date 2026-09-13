locals {
  oci_nlb_backend_bindings = {
    for binding in flatten([
      for listener_key, listener in var.oci_nlb_listeners : [
        for node_key, node in var.oci_edge_nodes : {
          key          = "${listener_key}/${node_key}"
          listener_key = listener_key
          node_key     = node_key
          instance_key = node.instance_key
          port         = coalesce(node.backend_port, listener.backend_port)
        }
      ]
    ]) : binding.key => binding
  }

  # Include both data-plane and health-check ports in the edge ingress rule.
  # A future HTTP readiness check therefore needs only a variable change.
  oci_nlb_edge_ingress_rules = {
    for rule in flatten([
      for listener_key, listener in var.oci_nlb_listeners : [
        for port in distinct(concat(
          [for node in values(var.oci_edge_nodes) : coalesce(node.backend_port, listener.backend_port)],
          [listener.health_check_port]
          )) : {
          key  = "${listener_key}/${port}"
          port = port
        }
      ]
    ]) : rule.key => rule
  }
}

resource "oci_core_network_security_group" "nlb" {
  compartment_id = local.oci_compartment_id
  display_name   = "edge-nlb"
  vcn_id         = oci_core_vcn.edge.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_core_network_security_group" "edge" {
  compartment_id = local.oci_compartment_id
  display_name   = "edge-nodes"
  vcn_id         = oci_core_vcn.edge.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_core_network_security_group_security_rule" "nlb_ingress" {
  for_each = var.oci_nlb_listeners

  description               = "Public TCP listener ${each.value.port}"
  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.nlb.id
  protocol                  = "6"
  source                    = "0.0.0.0/0"
  source_type               = "CIDR_BLOCK"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = each.value.port
      max = each.value.port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "nlb_to_edge" {
  for_each = local.oci_nlb_edge_ingress_rules

  description               = "NLB to edge TCP ${each.value.port}"
  destination               = oci_core_subnet.edge.cidr_block
  destination_type          = "CIDR_BLOCK"
  direction                 = "EGRESS"
  network_security_group_id = oci_core_network_security_group.nlb.id
  protocol                  = "6"
  stateless                 = false

  tcp_options {
    destination_port_range {
      min = each.value.port
      max = each.value.port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "edge_from_nlb" {
  for_each = local.oci_nlb_edge_ingress_rules

  description               = "NLB forwarded TCP ${each.value.port}"
  direction                 = "INGRESS"
  network_security_group_id = oci_core_network_security_group.edge.id
  protocol                  = "6"
  # Source preservation keeps the original client address, while the existing
  # subnet Security List already permits TCP/443. Keep this NSG rule scoped to
  # the NLB NSG and avoid broadening the managed NSG to 0.0.0.0/0.
  source      = oci_core_network_security_group.nlb.id
  source_type = "NETWORK_SECURITY_GROUP"
  stateless   = false

  tcp_options {
    destination_port_range {
      min = each.value.port
      max = each.value.port
    }
  }
}

resource "oci_core_network_security_group_security_rule" "edge_egress" {
  description               = "Edge nodes outbound access for OS updates and Tailscale"
  destination               = "0.0.0.0/0"
  destination_type          = "CIDR_BLOCK"
  direction                 = "EGRESS"
  network_security_group_id = oci_core_network_security_group.edge.id
  protocol                  = "all"
  stateless                 = false
}

resource "oci_network_load_balancer_network_load_balancer" "edge" {
  compartment_id             = local.oci_compartment_id
  display_name               = var.oci_nlb_display_name
  is_private                 = false
  network_security_group_ids = [oci_core_network_security_group.nlb.id]
  subnet_id                  = oci_core_subnet.edge.id

  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_network_load_balancer_backend_set" "edge" {
  for_each = var.oci_nlb_listeners

  is_fail_open             = false
  is_preserve_source       = each.value.preserve_source
  name                     = each.key
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.edge.id
  policy                   = "FIVE_TUPLE"

  health_checker {
    interval_in_millis = each.value.health_check_interval
    port               = each.value.health_check_port
    protocol           = each.value.health_check_protocol
    retries            = each.value.health_check_retries
    timeout_in_millis  = each.value.health_check_timeout
    url_path           = each.value.health_check_path
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_network_load_balancer_backend" "edge" {
  for_each = local.oci_nlb_backend_bindings

  backend_set_name         = oci_network_load_balancer_backend_set.edge[each.value.listener_key].name
  name                     = each.value.node_key
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.edge.id
  port                     = each.value.port
  target_id                = oci_core_instance.edge[each.value.instance_key].id
}

resource "oci_network_load_balancer_listener" "edge" {
  for_each = var.oci_nlb_listeners

  default_backend_set_name = oci_network_load_balancer_backend_set.edge[each.key].name
  is_ppv2enabled           = each.value.proxy_protocol_v2
  name                     = each.key
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.edge.id
  port                     = each.value.port
  protocol                 = each.value.protocol

  lifecycle {
    prevent_destroy = true
  }
}

data "oci_network_load_balancer_backend_set_health" "edge" {
  for_each = var.oci_nlb_listeners

  backend_set_name         = each.key
  network_load_balancer_id = oci_network_load_balancer_network_load_balancer.edge.id
}

output "oci_edge_nlb_id" {
  value = oci_network_load_balancer_network_load_balancer.edge.id
}

output "oci_edge_nlb_public_ips" {
  value = [
    for address in oci_network_load_balancer_network_load_balancer.edge.ip_addresses : address.ip_address
    if address.is_public
  ]
}

output "oci_edge_nlb_backend_health" {
  value = {
    for listener_key, health in data.oci_network_load_balancer_backend_set_health.edge : listener_key => {
      status                 = health.status
      total_backend_count    = health.total_backend_count
      critical_backend_names = health.critical_state_backend_names
      warning_backend_names  = health.warning_state_backend_names
      unknown_backend_names  = health.unknown_state_backend_names
    }
  }
}
