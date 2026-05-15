data "terraform_remote_state" "db" {
  backend = "s3"

  config = {
    bucket = var.remote_state_bucket
    key    = local.db_remote_state_key
    region = var.remote_state_region
  }
}

data "aws_ssm_parameter" "backend_listener" {
  name = local.backend_listener_ssm_parameter_name
}

data "aws_lambda_function" "auth" {
  function_name = var.auth_function_name
}

data "aws_lambda_function" "authorizer" {
  function_name = var.authorizer_function_name
}
