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

# Snowflake login the referral API (lambda.tf) reads the triage view with: the
# AI_PIPELINE_SVC user, same values as SNOWFLAKE_* in the repo-root .env.
# Set via TF_VAR_snowflake_api_* in infra/.env.
variable "snowflake_api_account" {
  description = "Snowflake account identifier for the referral API (e.g. ORG-ACCOUNT)."
  type        = string
}

variable "snowflake_api_user" {
  description = "Snowflake user the referral API connects as."
  type        = string
}

variable "snowflake_api_password" {
  description = "Password for snowflake_api_user."
  type        = string
  sensitive   = true
}

variable "snowflake_api_warehouse" {
  description = "Warehouse the referral API runs its query on."
  type        = string
  default     = "COMPUTE_WH"
}
