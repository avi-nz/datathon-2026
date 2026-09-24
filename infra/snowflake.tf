# A database is the top-level container; tables, views and stages live in its schemas.
resource "snowflake_database" "main" {
  name    = "REFERRAL_TRIAGE"
  comment = "Managed by Terraform"
}

# Second database for what the UI reads: AI results and the triage view.
# Kept apart from the raw/cleaned referral data in REFERRAL_TRIAGE.
resource "snowflake_database" "output_ui" {
  name    = "OUTPUT_UI"
  comment = "Managed by Terraform"
}

# Every database gets a PUBLIC schema automatically, so we use it rather than manage one.
locals {
  schema = "PUBLIC"
  fq     = "${snowflake_database.main.name}.PUBLIC" # REFERRAL_TRIAGE.PUBLIC, for SQL text
}

# A warehouse is the compute that runs queries. It's billed only while running,
# and auto_suspend shuts it down after 60 idle seconds.
# COMPUTE_WH comes with the account, so it was imported rather than created.
resource "snowflake_warehouse" "main" {
  name                = "COMPUTE_WH"
  warehouse_size      = var.snowflake_warehouse_size
  auto_suspend        = 60
  auto_resume         = "true"
  initially_suspended = true
  comment             = "Managed by Terraform"
}

