variable "vpc_cidr" {
  type = string
  default = "10.254.0.0/16"
}

variable "public_subnet_cidrs" {
  type = list(string)
  default = [
    "10.254.0.0/24",
    "10.254.1.0/24",
    "10.254.2.0/24",
  ]
}

variable "private_subnet_cidrs" {
  type = list(string)
  default = [
    "10.254.128.0/24",
    "10.254.129.0/24",
    "10.254.130.0/24"
  ]
}

variable "env" {
  type = string
}

variable "region" {
  type = string
}

variable "app_name" {
  type = string
}