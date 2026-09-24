USE WAREHOUSE COMPUTE_WH;
USE DATABASE REFERRAL_TRIAGE;
USE SCHEMA PUBLIC;

CREATE OR REPLACE FILE FORMAT CSV_STANDARD
    TYPE = 'CSV'
    FIELD_DELIMITER = ','
    SKIP_HEADER = 1
    FIELD_OPTIONALLY_ENCLOSED_BY = '"'
    NULL_IF = ('', 'NULL');

CREATE STAGE IF NOT EXISTS LOCATIONS_STAGE
    FILE_FORMAT = CSV_STANDARD;

LIST @LOCATIONS_STAGE

COPY INTO LOCATIONS (facility_id, facility_name, facility_type, latitude, longitude)
FROM @LOCATIONS_STAGE
FILE_FORMAT = CSV_STANDARD
ON_ERROR = 'CONTINUE';

CREATE STAGE IF NOT EXISTS SERVICES_STAGE   FILE_FORMAT = CSV_STANDARD;
CREATE STAGE IF NOT EXISTS PATIENTS_STAGE   FILE_FORMAT = CSV_STANDARD;
CREATE STAGE IF NOT EXISTS WORKFORCE_STAGE  FILE_FORMAT = CSV_STANDARD;
CREATE STAGE IF NOT EXISTS REFERRALS_STAGE  FILE_FORMAT = CSV_STANDARD;
CREATE STAGE IF NOT EXISTS BOOKINGS_STAGE FILE_FORMAT = CSV_STANDARD;

COPY INTO SERVICES (service_id, service_type, facility_id, eligibility_criteria, typical_wait_days)
FROM @SERVICES_STAGE 
FILE_FORMAT = CSV_STANDARD 
ON_ERROR = 'CONTINUE';

COPY INTO PATIENTS (patient_id, full_name, date_of_birth, age, gender, address, existing_conditions, risk_history, created_at)
FROM @PATIENTS_STAGE 
FILE_FORMAT = CSV_STANDARD 
ON_ERROR = 'CONTINUE';

COPY INTO WORKFORCE (staff_id, role, facility_id, service_id, capacity_hours, current_load)
FROM @WORKFORCE_STAGE 
FILE_FORMAT = CSV_STANDARD 
ON_ERROR = 'CONTINUE';

COPY INTO REFERRALS (referral_id, patient_id, service_id, facility_id, submitting_gp_id, submitted_at, reason_text, urgency_flag_gp, status)
FROM @REFERRALS_STAGE 
FILE_FORMAT = CSV_STANDARD 
ON_ERROR = 'CONTINUE';

COPY INTO BOOKINGS (booking_id, referral_id, staff_id, service_id, scheduled_at, status, duration_hours)
FROM @BOOKINGS_STAGE 
FILE_FORMAT = CSV_STANDARD 
ON_ERROR = 'CONTINUE';

SELECT COUNT(*) FROM SERVICES;
SELECT COUNT(*) FROM PATIENTS;
SELECT COUNT(*) FROM WORKFORCE;
SELECT COUNT(*) FROM REFERRALS;

-- spot-check a join actually resolves (confirms FK integrity holds)
SELECT r.referral_id, r.reason_text, s.service_type, l.facility_name
FROM REFERRALS r
JOIN SERVICES s ON r.service_id = s.service_id
JOIN LOCATIONS l ON r.facility_id = l.facility_id
LIMIT 5;

-- confirm dirty data actually made it in
SELECT * FROM PATIENTS WHERE address = '' OR address IS NULL LIMIT 5;
SELECT full_name, date_of_birth FROM PATIENTS WHERE date_of_birth LIKE '%/%' LIMIT 5;

-- confirm bookings joined correctly
SELECT b.booking_id, b.status, r.reason_text, w.role
FROM BOOKINGS b
JOIN REFERRALS r ON b.referral_id = r.referral_id
JOIN WORKFORCE w ON b.staff_id = w.staff_id
LIMIT 5;

CREATE STAGE IF NOT EXISTS P_GROUND_TRUTH_STAGE FILE_FORMAT = CSV_STANDARD;


CREATE OR REPLACE TABLE PATIENTS_GROUND_TRUTH_TEMP (
    patient_id VARCHAR, full_name VARCHAR, date_of_birth VARCHAR, age VARCHAR,
    gender VARCHAR, address VARCHAR, existing_conditions VARCHAR, risk_history VARCHAR,
    created_at VARCHAR, missing_fields VARCHAR, is_duplicate_of VARCHAR
);
COPY INTO PATIENTS_GROUND_TRUTH_TEMP FROM @P_GROUND_TRUTH_STAGE FILE_FORMAT = CSV_STANDARD ON_ERROR = 'CONTINUE';

SELECT COUNT(*) AS correct_matches
FROM PATIENTS p
JOIN PATIENTS_GROUND_TRUTH_TEMP gt ON p.patient_id = gt.patient_id
WHERE gt.is_duplicate_of != ''
  AND p.duplicate_of_patient_id = gt.is_duplicate_of;

-- false positives: we flagged a duplicate that wasn't actually one
SELECT COUNT(*) AS false_positives
FROM PATIENTS p
JOIN PATIENTS_GROUND_TRUTH_TEMP gt ON p.patient_id = gt.patient_id
WHERE p.duplicate_of_patient_id IS NOT NULL
  AND gt.is_duplicate_of = '';

-- false negatives: a real duplicate we missed entirely
SELECT COUNT(*) AS false_negatives
FROM PATIENTS p
JOIN PATIENTS_GROUND_TRUTH_TEMP gt ON p.patient_id = gt.patient_id
WHERE gt.is_duplicate_of != ''
  AND p.duplicate_of_patient_id IS NULL;


CREATE OR REPLACE STORAGE INTEGRATION S3_INTEGRATION
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::185658216984:role/snowflake-s3-access-role'
  STORAGE_ALLOWED_LOCATIONS = ('s3://referral-intake-bucket/');

DESC INTEGRATION S3_INTEGRATION;

CREATE OR REPLACE STAGE FORMAT_A_STAGE
  URL = 's3://referral-intake-bucket/format-a/'
  STORAGE_INTEGRATION = S3_INTEGRATION;

LIST @FORMAT_A_STAGE;

