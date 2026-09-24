terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    snowflake = {
      source  = "snowflakedb/snowflake"
      version = "~> 2.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.0"
    }
  }
}

# Credentials are read from environment variables so no secrets live in code:
#   SNOWFLAKE_ORGANIZATION_NAME, SNOWFLAKE_ACCOUNT_NAME, SNOWFLAKE_USER, SNOWFLAKE_PASSWORD, ...
# See .env.example.

# snowflake_table is still a "preview" resource in the provider and must be opted into.
locals {
  snowflake_preview_features = ["snowflake_table_resource"]
}

# Terraform runs as ACCOUNTADMIN, the same role used in Snowsight, so it owns
# (and can change) everything, including objects created there by hand.
provider "snowflake" {
  role                     = "ACCOUNTADMIN"
  preview_features_enabled = local.snowflake_preview_features
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}
