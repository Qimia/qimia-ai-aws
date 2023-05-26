locals {
  VPC_CIDR = "10.254.0.0/16"

  PublicSubnets = [
    "10.254.0.0/24",
    "10.254.1.0/24",
    "10.254.2.0/24",
  ]

  Avilability_Zones = [
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
  ]

  PrivateSubnets = [
    "10.254.128.0/24",
    "10.254.129.0/24",
    "10.254.130.0/24"
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
  availability_zone = "${local.region}${local.PublicSubnets[tonumber(each.key)]}"
}