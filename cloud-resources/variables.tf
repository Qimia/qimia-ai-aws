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
  default     = "906856305748"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "eu-central-1"
}

variable "model_machine_type" {
  description = "The machine type to use for the model, backend and frontend."
  type        = string
}
