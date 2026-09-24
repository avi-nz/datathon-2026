# ANALYST_ROLE is what the AI pipeline (backend/pipeline, via common/db.py) runs as,
# through the AI_PIPELINE_SVC user. The user itself is created by hand
# (infrastructure/snowflake/manual_setup.sql) so its password never lands in code or Terraform state.
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

# ---------- DATA_ENGINEER_ROLE: builds and loads the pipeline ----------
resource "snowflake_account_role" "data_engineer" {
  name = "DATA_ENGINEER_ROLE"
}

locals {
  data_engineer_role = snowflake_account_role.data_engineer.name
}

resource "snowflake_grant_privileges_to_account_role" "data_engineer_warehouse" {
  account_role_name = local.data_engineer_role
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.main.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "data_engineer_database" {
  for_each = toset([snowflake_database.main.name, snowflake_database.output_ui.name])

  account_role_name = local.data_engineer_role
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "DATABASE"
    object_name = each.key
  }
}

# USAGE on both schemas, plus the right to create objects in them: tables, stages,
# pipes and views in REFERRAL_TRIAGE.PUBLIC, and views only in OUTPUT_UI.PUBLIC.
resource "snowflake_grant_privileges_to_account_role" "data_engineer_schema" {
  for_each = {
    (snowflake_database.main.name)      = ["USAGE", "CREATE TABLE", "CREATE STAGE", "CREATE PIPE", "CREATE VIEW"]
    (snowflake_database.output_ui.name) = ["USAGE", "CREATE VIEW"]
  }

  account_role_name = local.data_engineer_role
  privileges        = each.value

  on_schema {
    schema_name = "\"${each.key}\".\"${local.schema}\""
  }
}

# Read and load every table in REFERRAL_TRIAGE.PUBLIC (raw and standardized).
# Like the SQL's ON ALL TABLES, this covers the tables that exist when it is applied.
resource "snowflake_grant_privileges_to_account_role" "data_engineer_referral_tables" {
  account_role_name = local.data_engineer_role
  privileges        = ["INSERT", "SELECT"]

  on_schema_object {
    all {
      object_type_plural = "TABLES"
      in_schema          = "\"${snowflake_database.main.name}\".\"${local.schema}\""
    }
  }

  depends_on = [snowflake_table.this]
}

resource "snowflake_grant_privileges_to_account_role" "data_engineer_ai_results" {
  account_role_name = local.data_engineer_role
  privileges        = ["SELECT"]

  on_schema_object {
    object_type = "TABLE"
    object_name = snowflake_table.this["AI_REFERRAL_RESULTS"].fully_qualified_name
  }
}

# ---------- VIEWER_ROLE: read-only access to the triage view ----------
# A view runs with its owner's privileges, so this role can read the view without
# any access to the REFERRAL_TRIAGE tables behind it.
resource "snowflake_account_role" "viewer" {
  name = "VIEWER_ROLE"
}

locals {
  viewer_role = snowflake_account_role.viewer.name
}

resource "snowflake_grant_privileges_to_account_role" "viewer_warehouse" {
  account_role_name = local.viewer_role
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "WAREHOUSE"
    object_name = snowflake_warehouse.main.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "viewer_database" {
  account_role_name = local.viewer_role
  privileges        = ["USAGE"]

  on_account_object {
    object_type = "DATABASE"
    object_name = snowflake_database.output_ui.name
  }
}

resource "snowflake_grant_privileges_to_account_role" "viewer_schema" {
  account_role_name = local.viewer_role
  privileges        = ["USAGE"]

  on_schema {
    schema_name = "\"${snowflake_database.output_ui.name}\".\"${local.schema}\""
  }
}

resource "snowflake_grant_privileges_to_account_role" "viewer_triage_view" {
  account_role_name = local.viewer_role
  privileges        = ["SELECT"]

  on_schema_object {
    object_type = "VIEW"
    object_name = snowflake_view.referral_triage.fully_qualified_name
  }
}
