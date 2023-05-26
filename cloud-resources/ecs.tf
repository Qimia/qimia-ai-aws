resource aws_ecs_cluster "app_cluster" {
  name = "qimia-ai-${var.env}"
}
#
## This is the role attached to the ECS cluster that allows it to do cluster management tasks such as pulling images from ECS etc.
#resource aws_iam_role execution {
#  name = "${var.env}"
#}
#
