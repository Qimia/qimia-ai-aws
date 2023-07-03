locals {
  app_name               = "${var.project}-${var.env}"
  secret_resource_prefix = "/${var.project}/${var.env}/"
  app_dns = lookup({
    "dev" : "qimiaai.com"
  }, var.env)
  backend_dns = lookup({
    "dev" : "api.qimiaai.com"
  }, var.env)

  frontend_dns = lookup({
    "dev" : "chat.qimiaai.com"
  }, var.env)
}
