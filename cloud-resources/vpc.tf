locals {
  VPC_CIDR = "10.254.0.0/16"

  PublicSubnets = [
    "10.254.0.0/24",
    "10.254.1.0/24",
    "10.254.2.0/24",
  ]

  Availability_Zones = [
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

data "aws_availability_zones" "region" {
  all_availability_zones = true
}

resource "aws_vpc" "the_vpc" {
  cidr_block = local.VPC_CIDR
  tags = {
    Name = "${var.env}-qimia-ai"
  }
}

resource "aws_subnet" "public" {
  for_each   = toset(["0", "1", "2"])
  vpc_id     = aws_vpc.the_vpc.id
  cidr_block = local.PublicSubnets[tonumber(each.key)]
  tags = {
    Name = "Public_${each.key}-${var.env}"
  }
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}${local.Availability_Zones[tonumber(each.key)]}"
}

resource "aws_subnet" "private" {
  for_each   = toset(["0", "1", "2"])
  vpc_id     = aws_vpc.the_vpc.id
  cidr_block = local.PrivateSubnets[tonumber(each.key)]
  tags = {
    Name = "Private_${each.key}-${var.env}"
  }
  map_public_ip_on_launch = false
  availability_zone       = "${var.region}${local.Availability_Zones[tonumber(each.key)]}"
}

#### Let's grant internet access to our public subnets
resource "aws_internet_gateway" "gateway" {
  tags = {
    Name = local.app_name
  }
  vpc_id = aws_vpc.the_vpc.id
}

resource "aws_route_table" "public_subnet_route" {
  vpc_id = aws_vpc.the_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gateway.id
  }
}

resource "aws_route_table_association" "public_subnets" {
  for_each       = toset(["0", "1", "2"])
  route_table_id = aws_route_table.public_subnet_route.id
  subnet_id      = aws_subnet.public[tonumber(each.key)].id
}
####