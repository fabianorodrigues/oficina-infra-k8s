locals {
  db_remote_state_key                 = length(trimspace(var.db_remote_state_key)) > 0 ? var.db_remote_state_key : "oficina-infra-db/${var.environment}/terraform.tfstate"
  backend_listener_ssm_parameter_name = length(trimspace(var.backend_listener_ssm_parameter_name)) > 0 ? var.backend_listener_ssm_parameter_name : "/${var.project_name}/${var.environment}/api/backend-listener-arn"
  public_base_url_ssm_parameter_name  = "/${var.project_name}/${var.environment}/api/public-base-url"
  name_prefix                         = lower("${var.project_name}-${var.environment}")
  backend_listener_arn                = sensitive(data.aws_ssm_parameter.backend_listener.value)
  auth_integration_uri                = sensitive(data.aws_lambda_function.auth.invoke_arn)
  auth_authorizer_uri                 = sensitive("arn:aws:apigateway:${var.aws_region}:lambda:path/2015-03-31/functions/${data.aws_lambda_function.authorizer.invoke_arn}/invocations")
  private_subnet_ids                  = data.terraform_remote_state.db.outputs.private_subnet_ids
  vpc_id                              = data.terraform_remote_state.db.outputs.vpc_id
  vpc_cidr_block                      = data.terraform_remote_state.db.outputs.vpc_cidr_block

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repository  = "oficina-infra-k8s"
  }
}
