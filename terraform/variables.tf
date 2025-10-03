variable "domain_name" {
  description = "Root domain name"
  type        = string
  default     = "wilsonwongcloud.com"
}

variable "bucket_name" {
  description = "S3 bucket name for the resume site"
  type        = string
  default     = "wilsonwong.wky-resume"
}

variable "lambda_function_name" {
  description = "Name of the Lambda function for visitor counter"
  type        = string
  default     = "VisitorCounter"
}

variable "acm_certificate_arn" {
  description = "ACM certificate ARN for HTTPS"
  type        = string
  default     = "arn:aws:acm:us-east-1:713881830177:certificate/ef93d639-46d6-4c42-a93c-6aee97825335"
}