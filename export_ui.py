import json
import os
from datetime import datetime, timezone
from decimal import Decimal

from snowflake.connector import DictCursor

from db import get_connection

# Written as a script (not plain JSON) so the page also works when index.html is opened
# straight from disk, where browsers block fetch() of local files.
OUTPUT_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "ui", "data", "referrals.js")

# VARIANT columns come back from the connector as JSON strings.
VARIANT_COLUMNS = {"probabilities", "justification"}


def normalise_row(row):
    """Lowercases Snowflake's upper-case column names and converts values to plain JSON types."""
    result = {}
    for key, value in row.items():
        key = key.lower()
        if key in VARIANT_COLUMNS and isinstance(value, str):
            value = json.loads(value)
        elif isinstance(value, Decimal):
            value = float(value)
        result[key] = value
    return result


def fetch_triage_view():
    conn = get_connection()
    cursor = conn.cursor(DictCursor)
    cursor.execute("SELECT * FROM OUTPUT_UI.PUBLIC.REFERRAL_TRIAGE_VIEW")
    rows = cursor.fetchall()
    cursor.close()
    conn.close()
    return [normalise_row(r) for r in rows]


def export_ui_data(path=OUTPUT_PATH):
    """Writes the triage view to the data file the UI reads. Returns the number of referrals written."""
    referrals = fetch_triage_view()
    payload = json.dumps(
        {"generated_at": datetime.now(timezone.utc).isoformat(), "referrals": referrals},
        indent=2,
        default=str,
    )
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(f"window.REFERRAL_DATA = {payload};\n")
    return len(referrals)


if __name__ == "__main__":
    count = export_ui_data()
    print(f"Exported {count} referrals to {OUTPUT_PATH}")
