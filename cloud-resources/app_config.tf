resource "aws_secretsmanager_secret" "admin_email" {
  name="${local.secret_resource_prefix}admin_email_address"
}

resource "aws_secretsmanager_secret" "admin_password" {
  name="${local.secret_resource_prefix}admin_email_password"
}

locals {
  app_config_map = {
    admin_email_address  = aws_secretsmanager_secret.admin_email.name
    admin_email_password = aws_secretsmanager_secret.admin_password.name
    email_password       = aws_secretsmanager_secret.email_password.name
    email_sender         = aws_secretsmanager_secret.email_address.name
    smtp_address         = aws_secretsmanager_secret.email_smtp_send_address.name
    db_password          = aws_secretsmanager_secret.postgres_master_password.name
    db_user              = aws_secretsmanager_secret.postgres_master_username.name
    db_host              = aws_secretsmanager_secret.postgres_host.name
    app_host             = aws_secretsmanager_secret.lb_url.name
    frontend_host        = aws_secretsmanager_secret.frontend_url.name
    token                = aws_secretsmanager_secret.postgres_host.name
  }
  app_config_lines = concat(
    ["[app_config]"],
    [
      for k in keys(local.app_config_map) :
      format(
        "app_config_%s_secret = \"%s\"",
        k,
        lookup(local.app_config_map, k)
      )
    ],
    [
      "app_config_deployment_mode = \"aws\"",
      "app_config_llama_host = \"tcp://localhost:5555\""
    ]
    )
  app_config_file = join("\n", local.app_config_lines)
}

resource "aws_s3_bucket" "devops_bucket" {
  bucket_prefix = local.app_name
}

resource "aws_s3_object" "app_config_file" {
  bucket = aws_s3_bucket.devops_bucket.bucket
  key = "${local.app_name}.appconfig.env"
  content = local.app_config_file
}