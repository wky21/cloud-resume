provider "aws" {
  region = "us-east-1"
}

# ---------------- S3 Bucket ----------------
resource "aws_s3_bucket" "resume" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_website_configuration" "resume" {
  bucket = aws_s3_bucket.resume.id
  index_document { suffix = "index.html" }
  error_document { key = "index.html" }
}
# ---------------- S3 Upload ----------------
#resource "aws_s3_object" "index_html" {
#  bucket       = aws_s3_bucket.resume.id
#  key          = "index.html"
#  source       = "${path.module}/website/index.html"
#  etag         = filemd5("${path.module}/website/index.html")
#  content_type = "text/html"
#}

# ---------------- CloudFront OAC ----------------
resource "aws_cloudfront_origin_access_control" "resume_oac" {
  name                              = "resume-oac"
  description                       = "OAC for Resume CloudFront"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
  origin_access_control_origin_type = "s3"
}

# CloudFront distribution
resource "aws_cloudfront_distribution" "resume_cdn" {
  enabled             = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.resume.bucket_regional_domain_name
    origin_id                = "resume-s3-origin"
    origin_access_control_id = aws_cloudfront_origin_access_control.resume_oac.id
  }

  default_cache_behavior {
    target_origin_id       = "resume-s3-origin"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]

    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
  }

  viewer_certificate {
  acm_certificate_arn      = var.acm_certificate_arn
  ssl_support_method       = "sni-only"
  minimum_protocol_version = "TLSv1.2_2021"
}


  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }
  aliases = [var.domain_name]
}

# Look up existing Route 53 hosted zone
data "aws_route53_zone" "resume" {
  name         = "wilsonwongcloud.com"
  private_zone = false
}

# Route 53 alias record for domain -> CloudFront
resource "aws_route53_record" "resume_alias" {
  zone_id = data.aws_route53_zone.resume.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.resume_cdn.domain_name
    zone_id                = aws_cloudfront_distribution.resume_cdn.hosted_zone_id
    evaluate_target_health = false
  }
}
# ---------------- S3 Bucket Policy (CloudFront OAC access) ----------------
resource "aws_s3_bucket_policy" "resume_policy" {
  bucket = aws_s3_bucket.resume.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = { Service = "cloudfront.amazonaws.com" },
        Action = "s3:GetObject",
        Resource = "${aws_s3_bucket.resume.arn}/*",
      }
    ]
  })
}

# ---------------- DynamoDB Table ----------------
resource "aws_dynamodb_table" "visitor_count" {
  name         = "VisitorCount"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

# ---------------- IAM Role for Lambda ----------------
resource "aws_iam_role" "lambda_role" {
  name = "resume-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy" "lambda_policy" {
  name = "resume-lambda-policy"
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      { Effect = "Allow", Action = ["dynamodb:UpdateItem","dynamodb:GetItem","dynamodb:PutItem"], Resource = aws_dynamodb_table.visitor_count.arn },
      { Effect = "Allow", Action = ["logs:CreateLogGroup","logs:CreateLogStream","logs:PutLogEvents"], Resource = "*" }
    ]
  })
}

# ---------------- Lambda Function ----------------
resource "aws_lambda_function" "visitor_counter" {
  function_name = var.lambda_function_name
  role          = aws_iam_role.lambda_role.arn
  runtime       = "python3.10"
  handler       = "visitor_counter.lambda_handler"
  filename      = "${path.module}/lambda/lambda.zip"

  environment {
    variables = { TABLE_NAME = aws_dynamodb_table.visitor_count.name }
  }
}

# ---------------- API Gateway HTTP API ----------------
resource "aws_apigatewayv2_api" "visitor_api" {
  name          = "VisitorAPI"
  protocol_type = "HTTP"

  cors_configuration {
    allow_origins = ["https://wilsonwongcloud.com"]
    allow_methods = ["GET", "OPTIONS"]
    allow_headers = ["*"]
    max_age       = 3600
  }
}
resource "aws_apigatewayv2_integration" "lambda_integration" {
  api_id           = aws_apigatewayv2_api.visitor_api.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.visitor_counter.invoke_arn
}

resource "aws_apigatewayv2_route" "get_count" {
  api_id    = aws_apigatewayv2_api.visitor_api.id
  route_key = "GET /"
  target    = "integrations/${aws_apigatewayv2_integration.lambda_integration.id}"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.visitor_api.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.visitor_counter.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.visitor_api.execution_arn}/*/*"
}

