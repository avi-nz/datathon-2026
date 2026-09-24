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
  }
}

# Credentials are read from environment variables so no secrets live in code:
#   SNOWFLAKE_ORGANIZATION_NAME, SNOWFLAKE_ACCOUNT_NAME, SNOWFLAKE_USER,
#   SNOWFLAKE_AUTHENTICATOR=SNOWFLAKE_JWT, SNOWFLAKE_PRIVATE_KEY (or SNOWFLAKE_PASSWORD)
provider "snowflake" {
  role = var.snowflake_role
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
