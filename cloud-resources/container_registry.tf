resource "aws_ecr_repository" "app_repo" {
  name = "${local.resource_name_prefix}"
}