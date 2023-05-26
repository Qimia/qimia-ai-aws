resource aws_ecs_cluster "app_cluster" {
  name = "qimia-ai-${var.env}"
}