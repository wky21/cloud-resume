output "cloudfront_domain" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.resume_cdn.domain_name
}

output "s3_bucket_name" {
  description = "S3 bucket name for resume site"
  value       = aws_s3_bucket.resume.id
}

output "api_gateway_url" {
  description = "Invoke URL for the API Gateway"
  value       = aws_apigatewayv2_stage.default.invoke_url
}

output "dynamodb_table_name" {
  description = "DynamoDB table name"
  value       = aws_dynamodb_table.visitor_count.name
}