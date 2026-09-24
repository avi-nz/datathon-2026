-- The only Snowflake object Terraform doesn't manage (infrastructure/terraform).
-- AI_PIPELINE_SVC is the service user the pipeline and referral API log in as
-- (SNOWFLAKE_USER in backend/.env). It is created by hand so its password never
-- lands in code or Terraform state. Run once, after `terraform apply` has created
-- ANALYST_ROLE and COMPUTE_WH.

CREATE USER IF NOT EXISTS AI_PIPELINE_SVC
    PASSWORD = '<set-a-strong-password>'
    DEFAULT_ROLE = ANALYST_ROLE
    DEFAULT_WAREHOUSE = COMPUTE_WH
    MUST_CHANGE_PASSWORD = FALSE;  -- service account, not a human login

GRANT ROLE ANALYST_ROLE TO USER AI_PIPELINE_SVC;
