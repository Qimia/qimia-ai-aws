resource "aws_ecr_repository" "app_repo" {
  name = "${var.env}-qimia-ai-llama"
}