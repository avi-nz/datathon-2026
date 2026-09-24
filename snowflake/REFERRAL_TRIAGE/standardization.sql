USE WAREHOUSE COMPUTE_WH;
USE DATABASE REFERRAL_TRIAGE;
USE SCHEMA PUBLIC;

-- Parser A: flat JSON, ISO timestamp already — no reformatting needed
INSERT INTO STANDARDIZED_REFERRALS
    (referral_id, nhi_number, reason_text, patient_age, existing_conditions,
     risk_history, facility_id, submitting_gp_id, submitted_at, source_format)
SELECT
    UUID_STRING(),                              -- referral_id generated HERE
    raw:nhi_number::VARCHAR,
    raw:gp_notes::VARCHAR,
    raw:age::INT,
    raw:existing_conditions::VARCHAR,
    raw:risk_history::VARCHAR,
    raw:facility_id::VARCHAR,
    raw:submitting_gp_id::VARCHAR,
    TRY_TO_TIMESTAMP(raw:submitted_at::VARCHAR),  -- already ISO, just parses cleanly
    'gp_form'
FROM RAW_FORMAT_A_REFERRALS;

-- Parser B: nested JSON, DD-MM-YYYY HH:MM — this is the actual date-format fix
INSERT INTO STANDARDIZED_REFERRALS
    (referral_id, nhi_number, reason_text, patient_age, existing_conditions,
     risk_history, facility_id, submitting_gp_id, submitted_at, source_format)
SELECT
    UUID_STRING(),                              -- referral_id generated HERE
    raw:patient.identifier::VARCHAR,
    raw:referral.clinicalNotes::VARCHAR,
    raw:patient.demographics.age::INT,
    raw:patient.clinicalHistory.conditions::VARCHAR,
    raw:patient.clinicalHistory.riskNotes::VARCHAR,
    raw:referral.facility::VARCHAR,
    raw:referral.referringGp::VARCHAR,
    TRY_TO_TIMESTAMP(raw:referral.timestamp::VARCHAR, 'DD-MM-YYYY HH24:MI'),  -- the date fix
    'referral_letter'
FROM RAW_FORMAT_B_REFERRALS;

SELECT * FROM STANDARDIZED_REFERRALS