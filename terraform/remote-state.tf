data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.remote_state_bucket
    key    = local.db_remote_state_key
    region = var.remote_state_region
  }
}
