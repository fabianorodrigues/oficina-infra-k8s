terraform {
  backend "s3" {
    key          = "oficina-infra-k8s/dev/api-gateway/terraform.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}
