USE WAREHOUSE COMPUTE_WH;
USE DATABASE REFERRAL_TRIAGE_OLD;
USE SCHEMA PUBLIC;

UPDATE PATIENTS
SET date_of_birth_clean = COALESCE(
    TRY_TO_DATE(date_of_birth, 'YYYY-MM-DD'),
    TRY_TO_DATE(date_of_birth, 'DD/MM/YYYY')
);

UPDATE PATIENTS
SET needs_review = TRUE,
    review_reason = 'unparseable date_of_birth'
WHERE date_of_birth_clean IS NULL;

UPDATE PATIENTS p1
SET duplicate_of_patient_id = p2.patient_id,
    needs_review = TRUE,
    review_reason = COALESCE(p1.review_reason || '; ', '') || 'possible duplicate patient'
FROM PATIENTS p2
WHERE p1.patient_id != p2.patient_id
  AND p1.date_of_birth_clean = p2.date_of_birth_clean
  AND JAROWINKLER_SIMILARITY(UPPER(p1.full_name), UPPER(p2.full_name)) > 85
  AND p1.created_at > p2.created_at;

UPDATE PATIENTS
SET needs_review = TRUE,
    review_reason = COALESCE(review_reason || '; ', '') || 'missing_fields'
WHERE age IS NULL
   OR gender IS NULL
   OR address IS NULL
   OR existing_conditions IS NULL;

-- overall summary
SELECT
    COUNT(*) AS total_patients,
    COUNT_IF(needs_review) AS flagged_for_review,
    COUNT_IF(duplicate_of_patient_id IS NOT NULL) AS duplicates_found,
    COUNT_IF(date_of_birth_clean IS NULL) AS unparseable_dates
FROM PATIENTS;

-- spot check flagged rows
SELECT patient_id, full_name, date_of_birth, date_of_birth_clean,
       duplicate_of_patient_id, needs_review, review_reason
FROM PATIENTS
WHERE needs_review = TRUE
LIMIT 20;

SELECT
    COUNT_IF(age IS NULL) AS null_ages,
    COUNT_IF(gender = '') AS empty_gender_strings,
    COUNT_IF(gender IS NULL) AS null_genders,
    COUNT_IF(address = '') AS empty_address_strings,
    COUNT_IF(address IS NULL) AS null_addresses,
    COUNT_IF(existing_conditions IS NULL) as null_conditions
FROM PATIENTS;
