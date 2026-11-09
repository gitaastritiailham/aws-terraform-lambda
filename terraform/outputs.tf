output "rds_endpoint" {
  value = aws_db_instance.rds.endpoint
}

output "api_gateway_url" {
  value = "${aws_apigatewayv2_api.http_api_new.api_endpoint}/products"
}