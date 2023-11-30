provider "aws" {
  region = "eu-west-2"
}

terraform {
  backend "s3" {
    bucket = "etl-holidays-backend"
    key    = "terraform.tfstate"
    region = "eu-west-2"
  }
}
