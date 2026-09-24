import time
import pandas as pd
import requests

PROXY_PIPELINE_URL = "http://localhost:8000/api/v1/referrals/ingest"
CSV_FILE_PATH = "patients.csv"


def stream_csv_referrals():
    print(f"Loading CSV dataset: '{CSV_FILE_PATH}'...")

    # Load dataset
    df = pd.read_csv(CSV_FILE_PATH)

    print(f"Found {len(df)} records. Starting streaming ingestion to Pipeline...\n")

    for index, row in df.iterrows():
        # Cleanly convert pandas NaN values to Python None (JSON null)
        age_val = None if pd.isna(row["age"]) else float(row["age"])
        gender_val = None if pd.isna(row["gender"]) else str(row["gender"])
        address_val = None if pd.isna(row["address"]) else str(row["address"])
        conditions_val = None if pd.isna(row["existing_conditions"]) else str(row["existing_conditions"])

        payload = {
            "source_interface_id": "GP_INTERFACE_EHR_BATCH",
            "patient_id": row["patient_id"],
            "full_name": row["full_name"],
            "date_of_birth": row["date_of_birth"],
            "age": age_val,
            "gender": gender_val,
            "address": address_val,
            "existing_conditions": conditions_val,
            "risk_history": row["risk_history"],
            "created_at": str(row["created_at"])
        }

        try:
            res = requests.post(PROXY_PIPELINE_URL, json=payload, timeout=5)
            print(
                f"[{index + 1}/{len(df)}] Sent {payload['patient_id']} ({payload['full_name']}) -> Status: {res.status_code}")
        except Exception as e:
            print(f"[{index + 1}/{len(df)}] Failed sending {payload['patient_id']}: {e}")

        # Pause briefly to simulate live incoming data flow
        time.sleep(0.1)


if __name__ == "__main__":
    stream_csv_referrals()