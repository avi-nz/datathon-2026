# A view is a saved SELECT; it stores no data and always shows the latest rows.
# This one is what the UI reads: each standardized referral plus its AI result
# (NULL columns until backend/pipeline/main.py has processed it).
resource "snowflake_view" "referral_triage" {
  database = snowflake_database.output_ui.name
  schema   = local.schema
  name     = "REFERRAL_TRIAGE_VIEW"

  statement = <<-SQL
    SELECT
        sr.referral_id,
        sr.nhi_number,
        sr.patient_age,
        sr.reason_text,
        sr.existing_conditions,
        sr.risk_history,
        sr.facility_id,
        sr.submitting_gp_id,
        ai.* EXCLUDE referral_id
    FROM ${snowflake_database.main.name}.${local.schema}.STANDARDIZED_REFERRALS AS sr
    LEFT JOIN ${snowflake_database.output_ui.name}.${local.schema}.AI_REFERRAL_RESULTS AS ai
        ON sr.referral_id = ai.referral_id
  SQL

  depends_on = [snowflake_table.this]
}
