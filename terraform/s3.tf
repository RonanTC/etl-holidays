resource "aws_s3_bucket" "code_bucket" {
  bucket_prefix = "etl-holidays-code-"
  force_destroy = true
}

resource "aws_s3_object" "db_init_code" {
  key    = "generator_code.zip"
  source = "${path.module}/../tmp/tmp_gen_code.zip"
  bucket = aws_s3_bucket.code_bucket.id
}
