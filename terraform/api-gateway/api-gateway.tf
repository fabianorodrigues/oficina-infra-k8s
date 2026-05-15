resource "aws_security_group" "vpc_link" {
  name        = "${local.name_prefix}-apigw-vpc-link-sg"
  description = "Security Group do VPC Link do API Gateway"
  vpc_id      = local.vpc_id

  tags = {
    Name = "${local.name_prefix}-apigw-vpc-link-sg"
  }
}

resource "aws_vpc_security_group_egress_rule" "vpc_link_to_backend" {
  security_group_id = aws_security_group.vpc_link.id
  description       = "HTTP egress to private backend"

  cidr_ipv4   = local.vpc_cidr_block
  from_port   = 80
  to_port     = 80
  ip_protocol = "tcp"

  tags = {
    Name = "${local.name_prefix}-vpc-link-to-backend"
  }
}

resource "aws_apigatewayv2_api" "this" {
  name          = "${local.name_prefix}-http-api"
  protocol_type = "HTTP"

  tags = {
    Name = "${local.name_prefix}-http-api"
  }
}

resource "aws_apigatewayv2_vpc_link" "this" {
  name               = "${local.name_prefix}-vpc-link"
  security_group_ids = [aws_security_group.vpc_link.id]
  subnet_ids         = local.private_subnet_ids

  tags = {
    Name = "${local.name_prefix}-vpc-link"
  }
}

resource "aws_apigatewayv2_integration" "backend" {
  api_id             = aws_apigatewayv2_api.this.id
  integration_type   = "HTTP_PROXY"
  integration_method = "ANY"
  integration_uri    = local.backend_listener_arn
  connection_type    = "VPC_LINK"
  connection_id      = aws_apigatewayv2_vpc_link.this.id
}

resource "aws_apigatewayv2_integration" "auth" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "AWS_PROXY"
  integration_uri        = local.auth_integration_uri
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_authorizer" "jwt" {
  api_id                            = aws_apigatewayv2_api.this.id
  name                              = "${local.name_prefix}-jwt-authorizer"
  authorizer_type                   = "REQUEST"
  authorizer_uri                    = local.auth_authorizer_uri
  authorizer_payload_format_version = "2.0"
  enable_simple_responses           = true
  identity_sources                  = ["$request.header.Authorization"]
}

resource "aws_apigatewayv2_route" "auth_cpf" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "POST /api/auth/cpf"
  target    = "integrations/${aws_apigatewayv2_integration.auth.id}"
}

resource "aws_apigatewayv2_route" "health" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "GET /health"
  target    = "integrations/${aws_apigatewayv2_integration.backend.id}"
}

resource "aws_apigatewayv2_route" "api_proxy" {
  api_id             = aws_apigatewayv2_api.this.id
  route_key          = "ANY /api/{proxy+}"
  target             = "integrations/${aws_apigatewayv2_integration.backend.id}"
  authorization_type = "CUSTOM"
  authorizer_id      = aws_apigatewayv2_authorizer.jwt.id
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  tags = {
    Name = "${local.name_prefix}-default-stage"
  }
}

resource "aws_lambda_permission" "auth" {
  statement_id  = "AllowExecutionFromApiGatewayAuth"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.auth.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/*/*"
}

resource "aws_lambda_permission" "authorizer" {
  statement_id  = "AllowExecutionFromApiGatewayAuthorizer"
  action        = "lambda:InvokeFunction"
  function_name = data.aws_lambda_function.authorizer.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.this.execution_arn}/authorizers/${aws_apigatewayv2_authorizer.jwt.id}"
}

resource "aws_ssm_parameter" "public_base_url" {
  name      = local.public_base_url_ssm_parameter_name
  type      = "String"
  value     = sensitive(aws_apigatewayv2_stage.default.invoke_url)
  overwrite = true

  tags = merge(local.common_tags, {
    Name = local.public_base_url_ssm_parameter_name
  })
}
