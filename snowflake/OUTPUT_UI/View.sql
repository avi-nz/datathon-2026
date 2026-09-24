USE WAREHOUSE COMPUTE_WH;
USE DATABASE OUTPUT_UI;
USE SCHEMA PUBLIC;

CREATE OR REPLACE VIEW OUTPUT_UI.PUBLIC.REFERRAL_TRIAGE_VIEW AS
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
FROM REFERRAL_TRIAGE.PUBLIC.STANDARDIZED_REFERRALS AS sr
LEFT JOIN OUTPUT_UI.PUBLIC.AI_REFERRAL_RESULTS AS ai
    ON sr.referral_id = ai.referral_id;

VIEW * FROM OUTPUT_UI.PUBLIC.REFERRAL_TRIAGE_VIEW

