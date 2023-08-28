data "aws_s3_bucket" "model_bucket" {
  bucket = var.model_bucket
}

data "aws_s3_object" "model_binary" {
  bucket = data.aws_s3_bucket.model_bucket.bucket
  key    = var.model_object_key
}