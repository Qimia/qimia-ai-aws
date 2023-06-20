resource "aws_ecr_repository" "app_repo" {
  name = local.app_name
}

resource "aws_ecr_repository" "frontend_repo" {
  name = "${var.project}-frontend-${var.env}"
}