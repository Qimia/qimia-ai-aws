terraform {
  required_providers {
    aws = {
      version = "~> 5.0.0"
    }
  }

  required_version = "~> 1.3.7"
}


locals {
  region = "eu-central-1"
  app_name = "qimia-ai-${var.env}"
  resource_name_prefix = local.app_name
}

terraform {
  backend "s3" {
    key    = "qimia-ai-infra"
    region = "eu-central-1"
  }
}

provider "aws" {
  region = "eu-central-1"
}