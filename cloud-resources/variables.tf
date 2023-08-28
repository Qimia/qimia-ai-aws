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

variable "model_bucket" {
  description = "The bucket where the model binary is located at. It must exist."
  type        = string
  default     = "qimia-ai-llm-foundation"
}

variable "model_object_key" {
  description = "The key of the model binary within the model bucket."
  type        = string
  default     = "ggml-vicuna-7b/ggml-vicuna-7b-q4_0-300523.bin"
}

variable "frontend_vcpu" {
  description = "The number of vCPU for the frontend container"
  type        = number
  default     = 0.5
}
variable "frontend_memory_gb" {
  description = "The memory for the frontend container"
  type        = number
  default     = 1.5
}

variable "webapi_vcpu" {
  description = "The number of vCPU for the webapi container."
  type        = number
  default     = 0.5
}
variable "webapi_memory_gb" {
  description = "The memory for the webapi container."
  type        = number
  default     = 1
}
variable "reserved_memory_gb" {
  description = "The reserved memory for the EC2 machine excluding the containers."
  type        = number
  default     = 1
}
variable "model_num_threads" {
  description = "The number of threads given to the model passed as an argument. Auto-derive if 0 otherwise set manually."
  type        = number
  default     = 2
}