data "aws_s3_bucket" "model_bucket" {
  bucket = "qimia-ai-llm-foundation"
}

data "aws_s3_object" model_binary {
  bucket = data.aws_s3_bucket.model_bucket.bucket
  key = "ggml-vicuna-7b/ggml-vicuna-7b-q4_0-300523.bin"
}