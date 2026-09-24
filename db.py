import os
import json
import snowflake.connector
from dotenv import load_dotenv

load_dotenv()

REQUIRED_ENV = ["SNOWFLAKE_ACCOUNT", "SNOWFLAKE_USER", "SNOWFLAKE_PASSWORD", "SNOWFLAKE_WAREHOUSE"]

def get_connection():
    missing = [name for name in REQUIRED_ENV if not os.getenv(name)]
    if missing:
        raise ValueError(f"Missing Snowflake settings in .env: {', '.join(missing)}")
    return snowflake.connector.connect(
        account=os.getenv("SNOWFLAKE_ACCOUNT"),
        user=os.getenv("SNOWFLAKE_USER"),
        password=os.getenv("SNOWFLAKE_PASSWORD"),
        warehouse=os.getenv("SNOWFLAKE_WAREHOUSE"),
    )

def fetch_unprocessed_referrals():
    """Returns referrals that don't yet have an AI result."""
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute("""
        SELECT sr.referral_id, sr.reason_text
        FROM REFERRAL_TRIAGE.PUBLIC.STANDARDIZED_REFERRALS sr
        LEFT JOIN OUTPUT_UI.PUBLIC.AI_REFERRAL_RESULTS ar
            ON sr.referral_id = ar.referral_id
        WHERE ar.referral_id IS NULL
          AND sr.reason_text IS NOT NULL
    """)
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    return [{"referral_id": r[0], "reason_text": r[1]} for r in rows]

def store_result(final_result):
    conn = get_connection()
    cursor = conn.cursor()
    cursor.execute(
        """
        INSERT INTO OUTPUT_UI.PUBLIC.AI_REFERRAL_RESULTS
            (referral_id, classification, confidence, probabilities, justification, recommendation)
        SELECT %s, %s, %s, PARSE_JSON(%s), PARSE_JSON(%s), %s
        """,
        (
            final_result["referral_id"],
            final_result["classification"],
            final_result["confidence"],
            json.dumps(final_result["probabilities"]),
            json.dumps(final_result["justification"]),
            final_result["recommendation"],
        ),
    )
    conn.commit()
    cursor.close()
    conn.close()