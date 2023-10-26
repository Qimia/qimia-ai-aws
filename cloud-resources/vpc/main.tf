locals {

  Availability_Zones = [
    "a",
    "b",
    "c",
    "d",
    "e",
    "f",
  ]
}



resource "aws_vpc" "the_vpc" {
  cidr_block = var.vpc_cidr
  tags = {
    Name = "${var.env}-qimia-ai"
  }
}

resource "aws_subnet" "public" {
  for_each   = toset(["0", "1", "2"])
  vpc_id     = aws_vpc.the_vpc.id
  cidr_block = var.public_subnet_cidrs[tonumber(each.key)]
  tags = {
    Name = "Public_${each.key}-${var.env}"
  }
  map_public_ip_on_launch = true
  availability_zone       = "${var.region}${local.Availability_Zones[tonumber(each.key)]}"
}

resource "aws_subnet" "private" {
  for_each   = toset(["0", "1", "2"])
  vpc_id     = aws_vpc.the_vpc.id
  cidr_block = var.private_subnet_cidrs[tonumber(each.key)]
  tags = {
    Name = "Private_${each.key}-${var.env}"
  }
  map_public_ip_on_launch = false
  availability_zone       = "${var.region}${local.Availability_Zones[tonumber(each.key)]}"
}

#### Let's grant internet access to our public subnets
resource "aws_internet_gateway" "gateway" {
  tags = {
    Name = var.app_name
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

output "vpc_id" {
  value = aws_vpc.the_vpc.id
}

output private_subnet_ids {
  value = [for subnet in aws_subnet.private : subnet.id]
}

output public_subnet_ids {
  value = [for subnet in aws_subnet.public : subnet.id]
}