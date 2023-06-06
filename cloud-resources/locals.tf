locals {
  app_name               = "${var.project}-${var.env}"
  secret_resource_prefix = "/${var.project}/${var.env}/"
}
