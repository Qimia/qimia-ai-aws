resource "aws_ecr_repository" "app_repo" {
  name = local.app_name
}