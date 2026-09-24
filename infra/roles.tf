# ANALYST_ROLE is what the AI pipeline (main.py via db.py) runs as, through the
# AI_PIPELINE_SVC user. Mirrors snowflake/OUTPUT_UI/Roles.sql. The user itself is
# created by hand so its password never lands in code or Terraform state.
#
# A role is a bundle of privileges; users get privileges only through roles.
resource "snowflake_account_role" "analyst" {
  name = "ANALYST_ROLE"
}

locals {
  analyst_role = snowflake_account_role.analyst.name
}

# To use anything inside a database, a role needs USAGE on the database, then
# USAGE on the schema, then a privilege on the object itself. Plus USAGE on a
# warehouse to run queries at all.
resource "snowflake_grant_privileges_to_account_role" "analyst_warehouse" {
  account_role_name = local.analyst_role
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.main.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_database" {
  for_each = toset([snowflake_database.main.name, snowflake_database.output_ui.name])

  account_role_name = local.analyst_role
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "DATABASE"
    object_name = each.key
  }
}

resource "snowflake_grant_privileges_to_account_role" "analyst_schema" {
  for_each = toset([snowflake_database.main.name, snowflake_database.output_ui.name])

  account_role_name = local.analyst_role
  privileges        = ["USAGE"]

  on_schema {
    schema_name = "\"${each.key}\".\"${local.schema}\""
  }
}

# Read the cleaned referrals (fetch_unprocessed_referrals).
resource "snowflake_grant_privileges_to_account_role" "analyst_read_referrals" {
  account_role_name = local.analyst_role
  privileges        = ["SELECT"]

  on_schema_object {
    object_type = "TABLE"
    object_name = snowflake_table.this["STANDARDIZED_REFERRALS"].fully_qualified_name
  }
}

# Read and write AI results (fetch_unprocessed_referrals + store_result).
resource "snowflake_grant_privileges_to_account_role" "analyst_ai_results" {
  account_role_name = local.analyst_role
  privileges        = ["INSERT", "SELECT"]

  on_schema_object {
    object_type = "TABLE"
    object_name = snowflake_table.this["AI_REFERRAL_RESULTS"].fully_qualified_name
  }
}

# Read the triage view the UI shows.
resource "snowflake_grant_privileges_to_account_role" "analyst_triage_view" {
  account_role_name = local.analyst_role
  privileges        = ["SELECT"]

  on_schema_object {
    object_type = "VIEW"
    object_name = snowflake_view.referral_triage.fully_qualified_name
  }
}
