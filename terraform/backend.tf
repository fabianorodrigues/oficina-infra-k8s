terraform {
  backend "s3" {
    key     = "oficina-infra-k8s/dev/terraform.tfstate"
    encrypt = true
  }
}
