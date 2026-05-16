data "terraform_remote_state" "core" {
  count = var.enable_new_relic ? 1 : 0

  backend = "s3"

  config = {
    bucket = var.remote_state_bucket
    key    = local.core_remote_state_key
    region = var.remote_state_region
  }
}
