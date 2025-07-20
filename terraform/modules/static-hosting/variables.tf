# terraform/modules/static-hosting/variables.tf

# NOTE: For custom domain SSL certificates, ACM requires certificates for CloudFront
# to be created in the us-east-1 region. In a production setup, you would need to
# configure a provider alias in your root configuration:
#
# provider "aws" {
#   alias  = "us_east_1"
#   region = "us-east-1"
# }

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "education-platform"
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the website (optional)"
  type        = string
  default     = ""
}

variable "subdomain" {
  description = "Subdomain for the website (e.g. www, app)"
  type        = string
  default     = "app"
}

variable "enable_custom_domain" {
  description = "Whether to enable custom domain with SSL certificate"
  type        = bool
  default     = false
}

variable "create_route53_zone" {
  description = "Whether to create a new Route53 hosted zone"
  type        = bool
  default     = false
}

variable "enable_cloudfront_logging" {
  description = "Whether to enable CloudFront access logging"
  type        = bool
  default     = true
}

variable "cloudfront_price_class" {
  description = "CloudFront price class (PriceClass_All, PriceClass_200, PriceClass_100)"
  type        = string
  default     = "PriceClass_100"
}

variable "s3_force_destroy" {
  description = "Whether to force destroy S3 bucket (useful for development)"
  type        = bool
  default     = false
}

variable "cors_allowed_origins" {
  description = "List of allowed origins for CORS"
  type        = list(string)
  default     = ["*"]
}

variable "cloudfront_default_ttl" {
  description = "Default TTL for CloudFront cache"
  type        = number
  default     = 86400  # 1 day
}

variable "cloudfront_max_ttl" {
  description = "Maximum TTL for CloudFront cache"
  type        = number
  default     = 31536000  # 1 year
}

variable "s3_versioning_enabled" {
  description = "Whether to enable S3 bucket versioning"
  type        = bool
  default     = true
}

variable "s3_lifecycle_enabled" {
  description = "Whether to enable S3 lifecycle management"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Additional tags to apply to resources"
  type        = map(string)
  default     = {}
}
