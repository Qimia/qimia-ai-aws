locals {
  VPC_CIDR = "10.254.0.0/16"

  PublicSubnet1_CIDR = "10.254.0.0/24"
  PublicSubnet2_CIDR = "10.254.1.0/24"
  PublicSubnet3_CIDR = "10.254.2.0/24"

  PublicSubnets = [
    local.PublicSubnet1_CIDR,
    local.PublicSubnet2_CIDR,
    local.PublicSubnet3_CIDR
  ]

  PrivateSubnet1_CIDR = "10.254.128.0/24"
  PrivateSubnet2_CIDR = "10.254.129.0/24"
  PrivateSubnet3_CIDR = "10.254.130.0/24"

  PrivateSubnets = [
    local.PrivateSubnet1_CIDR,
    local.PrivateSubnet2_CIDR,
    local.PrivateSubnet3_CIDR,
  ]
}

data aws_availability_zones region {
  all_availability_zones = true
}

resource "aws_vpc" "the_vpc" {
  cidr_block = local.VPC_CIDR
  tags = {
    Name = "${var.env}-qimia-ai"
  }
}

resource aws_subnet public {
  for_each = toset(["0", "1", "2"])
  vpc_id = aws_vpc.the_vpc.id
  cidr_block = local.PublicSubnets[tonumber(each.key)]
  tags = {
    Name = "Public_${each.key}"
  }
  map_public_ip_on_launch = true
  availability_zone = sort(data.aws_availability_zones.region.names)[tonumber(each.key)]
}