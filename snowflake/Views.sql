USE WAREHOUSE COMPUTE_WH;
USE DATABASE REFERRAL_TRIAGE_OLD;
USE SCHEMA PUBLIC;


-- Create View V_TRIANGLE_QUEUE for coordinator to view relevant information needed for each referrals
CREATE OR REPLACE VIEW V_TRIAGE_QUEUE AS
SELECT
    r.referral_id,
    r.submitted_at,
    r.status,
    r.reason_text,
    r.urgency_flag_gp,
    r.ai_triage_score,
    r.ai_risk_flag,
    r.ai_summary,
    p.age              AS patient_age,
    p.gender           AS patient_gender,
    p.existing_conditions,     -- automatically masked per-role, per your masking policy
    p.risk_history,
    s.service_type,
    s.typical_wait_days,
    l.facility_name

FROM REFERRALS r
JOIN PATIENTS p   ON r.patient_id  = p.patient_id
JOIN SERVICES s   ON r.service_id  = s.service_id
JOIN LOCATIONS l  ON r.facility_id = l.facility_id
ORDER BY r.ai_triage_score DESC NULLS LAST, r.submitted_at ASC;

-- Create View for checking staff availability
CREATE OR REPLACE VIEW V_WORKFORCE_CAPACITY AS
SELECT
    w.staff_id,
    w.role,
    l.facility_name,
    s.service_type,
    w.capacity_hours,
    w.current_load,
    ROUND(w.capacity_hours - w.current_load, 1) AS available_hours,
    ROUND((w.current_load / w.capacity_hours) * 100, 1) AS utilization_pct
FROM WORKFORCE w
JOIN LOCATIONS l ON w.facility_id = l.facility_id
JOIN SERVICES s  ON w.service_id  = s.service_id
ORDER BY utilization_pct ASC;

CREATE OR REPLACE VIEW V_PATIENT_REVIEW_QUEUE AS
SELECT
    p.patient_id,
    p.full_name,
    p.date_of_birth,
    p.date_of_birth_clean,
    p.duplicate_of_patient_id,
    p.review_reason,
    p.created_at,
    r.referral_id,
    r.reason_text,
    r.submitting_gp_id,
    l.facility_name
FROM PATIENTS p
JOIN REFERRALS r ON p.patient_id = r.patient_id
LEFT JOIN LOCATIONS l ON r.facility_id = l.facility_id
WHERE p.needs_review = TRUE
  AND p.reviewed = FALSE
ORDER BY p.created_at ASC;


