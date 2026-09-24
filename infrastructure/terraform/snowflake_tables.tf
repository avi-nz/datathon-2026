# Table definitions for the raw, standardized and AI result tables. Primary keys are left out: Snowflake
# records them but never enforces them. The NOT NULL they implied is kept
# (nullable = false), because Snowflake does enforce that.
locals {
  tables = {
    # Raw landing tables: one row per JSON file record, kept exactly as received.
    # VARIANT is Snowflake's semi-structured type; query it with raw:field::TYPE.
    RAW_FORMAT_A_REFERRALS = {
      database        = snowflake_database.main.name
      change_tracking = true # needed by the stream on this table (referral_intake.tf)
      columns = [
        { name = "RAW", type = "VARIANT" },
        { name = "LOADED_AT", type = "TIMESTAMP_NTZ(9)", default = "CURRENT_TIMESTAMP()" },
      ]
    }
    RAW_FORMAT_B_REFERRALS = {
      database        = snowflake_database.main.name
      change_tracking = true # needed by the stream on this table (referral_intake.tf)
      columns = [
        { name = "RAW", type = "VARIANT" },
        { name = "LOADED_AT", type = "TIMESTAMP_NTZ(9)", default = "CURRENT_TIMESTAMP()" },
      ]
    }
    # Both formats parsed into one shape (see the task in referral_intake.tf).
    STANDARDIZED_REFERRALS = {
      database = snowflake_database.main.name
      columns = [
        { name = "REFERRAL_ID", type = "VARCHAR(16777216)", nullable = false },
        { name = "NHI_NUMBER", type = "VARCHAR(16777216)" },
        { name = "REASON_TEXT", type = "VARCHAR(16777216)" },
        { name = "PATIENT_AGE", type = "NUMBER(38,0)" },
        { name = "EXISTING_CONDITIONS", type = "VARCHAR(16777216)" },
        { name = "RISK_HISTORY", type = "VARCHAR(16777216)" },
        { name = "FACILITY_ID", type = "VARCHAR(16777216)" },
        { name = "SUBMITTING_GP_ID", type = "VARCHAR(16777216)" },
        { name = "SUBMITTED_AT", type = "TIMESTAMP_NTZ(9)" },
        { name = "SOURCE_FORMAT", type = "VARCHAR(16777216)" }, # gp_form (A) or referral_letter (B)
        { name = "STANDARDIZED_AT", type = "TIMESTAMP_NTZ(9)", default = "CURRENT_TIMESTAMP()" },
      ]
    }
    # Written by backend/pipeline/main.py (common/db.py store_result) after the AI classifies a referral.
    AI_REFERRAL_RESULTS = {
      database = snowflake_database.output_ui.name
      columns = [
        { name = "REFERRAL_ID", type = "VARCHAR(16777216)", nullable = false },
        { name = "CLASSIFICATION", type = "VARCHAR(16777216)" },
        { name = "CONFIDENCE", type = "FLOAT" },
        { name = "PROBABILITIES", type = "VARIANT" },
        { name = "JUSTIFICATION", type = "VARIANT" },
        { name = "RECOMMENDATION", type = "VARCHAR(16777216)" },
        { name = "PROCESSED_AT", type = "TIMESTAMP_NTZ(9)", default = "CURRENT_TIMESTAMP()" },
      ]
    }
  }
}

# A standard Snowflake table. Storage is columnar and billed separately from compute.
resource "snowflake_table" "this" {
  for_each = local.tables

  database        = each.value.database
  schema          = local.schema
  name            = each.key
  change_tracking = lookup(each.value, "change_tracking", false)

  dynamic "column" {
    for_each = each.value.columns
    content {
      name     = column.value.name
      type     = column.value.type
      nullable = lookup(column.value, "nullable", true)

      dynamic "default" {
        for_each = lookup(column.value, "default", null) == null ? [] : [column.value.default]
        content {
          expression = default.value
        }
      }
    }
  }
}
