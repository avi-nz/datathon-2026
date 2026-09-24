USE WAREHOUSE COMPUTE_WH;
USE DATABASE OUTPUT_UI;
USE SCHEMA PUBLIC;

CREATE TABLE IF NOT EXISTS AI_REFERRAL_RESULTS (
    referral_id       VARCHAR PRIMARY KEY,
    classification    VARCHAR,
    confidence        FLOAT,
    probabilities     VARIANT,
    justification     VARIANT,
    recommendation    VARCHAR,
    processed_at      TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

