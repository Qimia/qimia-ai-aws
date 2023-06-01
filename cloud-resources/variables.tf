# Project Variables
variable "project" {
  description = "Project Name"
  type        = string
  default     = "qimia-ai"
}

variable "env" {
  description = "Infra Structure Environment"
  type        = string
  default     = "dev"
}
variable "account" {
  description = "AWS Account ID"
  type        = number
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}