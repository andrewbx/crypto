module "bitcoin" {
  source = "./modules/nodes"

  coin_name = "bitcoin"
  image_id = var.node_ami_id

  vpc_id                = data.aws_vpc.vpc.id
  availability_zones    = data.aws_availability_zones.zones.names
  subnet_ids            = data.aws_subnet_ids.nodes.ids
  domain_intern_zone_id = data.aws_route53_zone.internal.zone_id

  instance_type = "c5.large"
  nodes_num     = var.nodes_num

  root_volume = 16
  ebs_size    = 500

  rpc_ports = [
    8332
  ]

  p2p_ports = [
    8333
  ]

  has_secrets = true

  host_config = {
    DATA_VOLUME = "/node/data"
  }

  container_config = {
    RPC_PORT = "8332"
    PORT     = "8333"
    ...
  }

  custom_metrics = {
    Component = file("${path.module}/custom-metrics/metrics.sh")
  }

  tags = merge(
    {
      Component = "nodes/bitcoin"
    },
    var.tags
  )
}
