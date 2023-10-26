module "the_vpc" {
  source = "./vpc"
  app_name = local.app_name
  env = var.env
  region = var.region
  count = var.create_vpc
}

data "aws_vpc" "the_vpc" {
  depends_on = [module.the_vpc]
  id = var.create_vpc == 1 ? module.the_vpc[0].vpc_id : var.vpc_id
}

data "aws_subnet" "private" {
  depends_on = [module.the_vpc]
  for_each = var.create_vpc == 1 ? {
    one = module.the_vpc[0].private_subnet_ids[0]
    two = module.the_vpc[0].private_subnet_ids[1]
    three = module.the_vpc[0].private_subnet_ids[2]
  } : {
    one = var.private_subnet_ids[0]
    two = var.private_subnet_ids[1]
    three = var.private_subnet_ids[2]
  }
  id = each.value
}

data "aws_subnet" "public" {
  depends_on = [module.the_vpc]
  for_each = var.create_vpc == 1 ? {
    one = module.the_vpc[0].public_subnet_ids[0]
    two = module.the_vpc[0].public_subnet_ids[1]
    three = module.the_vpc[0].public_subnet_ids[2]
  } : {
    one = var.public_subnet_ids[0]
    two = var.public_subnet_ids[1]
    three = var.public_subnet_ids[2]
  }
  id = each.value
}