USE WAREHOUSE COMPUTE_WH;
USE DATABASE REFERRAL_TRIAGE;
USE SCHEMA PUBLIC;

-- LOCATIONS 
CREATE OR REPLACE TABLE LOCATIONS (
    facility_id     VARCHAR PRIMARY KEY,
    facility_name   VARCHAR,
    facility_type   VARCHAR,     
    latitude        FLOAT,
    longitude       FLOAT
);

-- SERVICES
CREATE OR REPLACE TABLE SERVICES (
    service_id      VARCHAR PRIMARY KEY,
    service_type    VARCHAR,
    facility_id     VARCHAR REFERENCES LOCATIONS(facility_id),
    eligibility_criteria VARCHAR,
    typical_wait_days INT
);

-- PATIENTS
CREATE OR REPLACE TABLE PATIENTS (
    patient_id      VARCHAR PRIMARY KEY,
    full_name       VARCHAR,
    date_of_birth   VARCHAR,
    address         VARCHAR,
    age             INT,
    gender          VARCHAR,
    existing_conditions VARCHAR,   
    risk_history    VARCHAR
);

-- WORKFORCE
CREATE OR REPLACE TABLE WORKFORCE (
    staff_id        VARCHAR PRIMARY KEY,
    role            VARCHAR, -- Job title / Seniority 
    facility_id     VARCHAR REFERENCES LOCATIONS(facility_id),
    service_id      VARCHAR REFERENCES SERVICES(service_id), -- what service each staff is working in 
    capacity_hours  FLOAT,
    current_load    FLOAT
);

-- REFERRALS (fact table)
CREATE OR REPLACE TABLE REFERRALS (
    referral_id       VARCHAR PRIMARY KEY,
    patient_id        VARCHAR REFERENCES PATIENTS(patient_id),
    service_id        VARCHAR REFERENCES SERVICES(service_id),
    facility_id       VARCHAR REFERENCES LOCATIONS(facility_id),
    assigned_staff_id VARCHAR REFERENCES WORKFORCE(staff_id),
    submitting_gp_id  VARCHAR,
    submitted_at      TIMESTAMP_NTZ,
    reason_text       VARCHAR,     -- free text from GP
    urgency_flag_gp   VARCHAR,     -- GP's own rating, if collected
    status            VARCHAR DEFAULT 'pending',
    ai_label           
    ai_justification
    ai_nextstep
    ai_confidence
    
);

CREATE TABLE BOOKINGS (
    booking_id      VARCHAR PRIMARY KEY,
    referral_id     VARCHAR REFERENCES REFERRALS(referral_id),
    staff_id        VARCHAR REFERENCES WORKFORCE(staff_id),
    service_id      VARCHAR REFERENCES SERVICES(service_id),
    scheduled_at    TIMESTAMP_NTZ,
    status          VARCHAR,  -- 'scheduled', 'completed', 'cancelled', 'no_show'
    duration_hours  FLOAT
);

-- AUDIT_LOG (tracks every automated action)
CREATE OR REPLACE TABLE AUDIT_LOG (
    log_id          VARCHAR PRIMARY KEY,
    referral_id     VARCHAR REFERENCES REFERRALS(referral_id),
    action_type     VARCHAR,     -- e.g. routed, reminder_sent, escalated
    action_detail   VARCHAR,
    performed_by    VARCHAR,     -- 'system' or a staff_id
    performed_at    TIMESTAMP_NTZ
);

ALTER TABLE PATIENTS ADD COLUMN date_of_birth_clean DATE;
ALTER TABLE PATIENTS ADD COLUMN duplicate_of_patient_id VARCHAR;
ALTER TABLE PATIENTS ADD COLUMN needs_review BOOLEAN DEFAULT FALSE;
ALTER TABLE PATIENTS ADD COLUMN review_reason VARCHAR;
ALTER TABLE PATIENTS ADD COLUMN created_at TIMESTAMP_NTZ;
ALTER TABLE PATIENTS ADD COLUMN reviewed BOOLEAN DEFAULT FALSE;
ALTER TABLE PATIENTS ADD COLUMN reviewed_at TIMESTAMP_NTZ;
ALTER TABLE PATIENTS ADD COLUMN reviewed_by VARCHAR;  -- staff_id or username of whoever resolved it