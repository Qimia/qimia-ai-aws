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
}

terraform {
  backend "s3" {
    key    = "qimia-ai-infra"
    region = "eu-central-1"
  }
}
