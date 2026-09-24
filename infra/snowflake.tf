locals {
  snowflake_prefix = upper(replace("${var.project_name}_${var.environment}", "-", "_"))
}

resource "snowflake_database" "main" {
  name    = local.snowflake_prefix
  comment = "Managed by Terraform"
}

resource "snowflake_warehouse" "main" {
  name                = "${local.snowflake_prefix}_WH"
  warehouse_size      = var.snowflake_warehouse_size
  auto_suspend        = 60
  auto_resume         = "true"
  initially_suspended = true
  comment             = "Managed by Terraform"
}
