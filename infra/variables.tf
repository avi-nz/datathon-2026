variable "aws_region" {
  description = "AWS region for the S3 bucket."
  type        = string
  default     = "ap-southeast-2"
}

variable "project_name" {
  description = "Project name, used in resource names and tags."
  type        = string
  default     = "datathon-2026"
}

variable "environment" {
  description = "Deployment environment (e.g. dev, prod)."
  type        = string
  default     = "dev"
}

variable "price_class" {
  description = "CloudFront price class."
  type        = string
  default     = "PriceClass_100"
}

variable "snowflake_warehouse_size" {
  description = "Size of the Snowflake warehouse."
  type        = string
  default     = "XSMALL"
}

variable "referral_load_schedule_minutes" {
  description = "How often (minutes) Snowflake loads new referral files from S3 and standardizes them."
  type        = number
  default     = 60
}
