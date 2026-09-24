USE WAREHOUSE COMPUTE_WH;
USE DATABASE REFERRAL_TRIAGE;
USE SCHEMA PUBLIC;

CREATE OR REPLACE TABLE RAW_FORMAT_A_REFERRALS (
    raw       VARIANT,
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

CREATE OR REPLACE TABLE RAW_FORMAT_B_REFERRALS (
    raw       VARIANT,
    loaded_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- This will only be run after the pipeline between S3 and snowflake is establish
-- Two external stages, pointing at your real S3 bucket via the storage integration
CREATE OR REPLACE STAGE FORMAT_A_S3_STAGE
  URL = 's3://<your-bucket-name>/format-a/'
  STORAGE_INTEGRATION = S3_INTEGRATION
  FILE_FORMAT = JSON_STANDARD;

CREATE OR REPLACE STAGE FORMAT_B_S3_STAGE
  URL = 's3://<your-bucket-name>/format-b/'
  STORAGE_INTEGRATION = S3_INTEGRATION
  FILE_FORMAT = JSON_STANDARD;

-- Two pipes: auto-ingest whatever new files land in each folder
CREATE OR REPLACE PIPE FORMAT_A_PIPE
  AUTO_INGEST = TRUE
  AS COPY INTO RAW_FORMAT_A_REFERRALS (raw) FROM @FORMAT_A_S3_STAGE FILE_FORMAT = JSON_STANDARD;

CREATE OR REPLACE PIPE FORMAT_B_PIPE
  AUTO_INGEST = TRUE
  AS COPY INTO RAW_FORMAT_B_REFERRALS (raw) FROM @FORMAT_B_S3_STAGE FILE_FORMAT = JSON_STANDARD;

CREATE OR REPLACE TABLE STANDARDIZED_REFERRALS (
    referral_id          VARCHAR PRIMARY KEY,
    nhi_number           VARCHAR,
    reason_text          VARCHAR,
    patient_age          INT,
    existing_conditions  VARCHAR,
    risk_history         VARCHAR,
    facility_id          VARCHAR,
    submitting_gp_id     VARCHAR,
    submitted_at         TIMESTAMP_NTZ,   -- standardized date lands here
    source_format        VARCHAR,
    standardized_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);



