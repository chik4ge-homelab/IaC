data "oci_core_vcn" "edge_existing" {
  vcn_id = local.oci_vcn_id
}

data "oci_core_subnet" "edge_existing" {
  subnet_id = local.oci_subnet_id
}

# These are existing shared network resources. Import them before apply so
# Terraform records ownership without creating or replacing the network.
resource "oci_core_vcn" "edge" {
  compartment_id = local.oci_compartment_id
  cidr_blocks    = data.oci_core_vcn.edge_existing.cidr_blocks
  display_name   = data.oci_core_vcn.edge_existing.display_name
  dns_label      = data.oci_core_vcn.edge_existing.dns_label

  lifecycle {
    prevent_destroy = true
  }
}

resource "oci_core_subnet" "edge" {
  compartment_id             = local.oci_compartment_id
  cidr_block                 = data.oci_core_subnet.edge_existing.cidr_block
  display_name               = data.oci_core_subnet.edge_existing.display_name
  prohibit_public_ip_on_vnic = data.oci_core_subnet.edge_existing.prohibit_public_ip_on_vnic
  route_table_id             = data.oci_core_subnet.edge_existing.route_table_id
  security_list_ids          = data.oci_core_subnet.edge_existing.security_list_ids
  vcn_id                     = oci_core_vcn.edge.id

  lifecycle {
    prevent_destroy = true
  }
}

output "oci_edge_subnet" {
  value = {
    id         = oci_core_subnet.edge.id
    cidr_block = oci_core_subnet.edge.cidr_block
    vcn_id     = oci_core_vcn.edge.id
  }
}
