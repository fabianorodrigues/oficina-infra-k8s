output "api_gateway_url" {
  description = "URL publica do API Gateway HTTP API."
  value       = aws_apigatewayv2_stage.default.invoke_url
  sensitive   = true
}

output "api_gateway_id" {
  description = "ID do API Gateway HTTP API."
  value       = aws_apigatewayv2_api.this.id
  sensitive   = true
}
