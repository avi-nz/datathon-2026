"""
Reads the AI triage results from Snowflake in the shape the web UI expects.

Pipeline position:
    GP referral -> Jev (urgency) -> Claude Haiku (justification + next step)
    -> Snowflake (AI_REFERRAL_RESULTS) -> REFERRAL_TRIAGE_VIEW -> THIS MODULE
    -> GET /referrals (api/app.py) -> frontend/index.html
"""

import json
from decimal import Decimal

from snowflake.connector import DictCursor

from common.db import get_connection

# The connector returns VARIANT columns as JSON strings, so these are parsed back into dicts
# before export; otherwise the UI would receive JSON-inside-a-string.
VARIANT_COLUMNS = {"probabilities", "justification"}


def normalise_row(row):
    """Lowercases Snowflake's upper-case column names and converts values to plain JSON types."""
    result = {}
    for key, value in row.items():
        key = key.lower()
        if key in VARIANT_COLUMNS and isinstance(value, str):
            value = json.loads(value)
        elif isinstance(value, Decimal):
            # NUMBER columns come back as Decimal, which json can't serialise.
            value = float(value)
        result[key] = value
    return result


def fetch_triage_view():
    """Reads every row of the triage view from Snowflake and returns them as a list of dicts."""
    conn = get_connection()
    cursor = conn.cursor(DictCursor)
    # The view LEFT JOINs referrals to AI results, so unprocessed referrals are included too
    # (with empty AI columns) and show up in the UI's "Awaiting AI triage" tab.
    cursor.execute("SELECT * FROM OUTPUT_UI.PUBLIC.REFERRAL_TRIAGE_VIEW")
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    return [normalise_row(r) for r in rows]
