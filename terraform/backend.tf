terraform {
  backend "s3" {
    key     = "oficina-infra-k8s/academy/terraform.tfstate"
    encrypt = true
  }
}
