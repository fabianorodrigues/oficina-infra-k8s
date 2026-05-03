terraform {
  backend "s3" {
    key     = "oficina-infra-k8s/academy/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
  }
}

