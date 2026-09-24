"""
Serves the referral triage view as JSON, for the web UI.

GET /referrals returns every row of OUTPUT_UI.PUBLIC.REFERRAL_TRIAGE_VIEW: each standardised GP
referral joined to its AI result (null AI fields until main.py has processed it). Same shape as
the data export_ui.py writes: { generated_at: "<ISO timestamp>", referrals: [ {...}, ... ] }.

Runs on AWS Lambda through Mangum (see infra/lambda.tf). Run it locally from the repo root with:
    PYTHONPATH=. uv run --with-requirements backend/requirements.txt --with uvicorn uvicorn backend.app:app
"""

from datetime import datetime, timezone

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from mangum import Mangum

from export_ui import fetch_triage_view

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["GET"])


@app.get("/referrals")
def list_referrals():
    return {"generated_at": datetime.now(timezone.utc).isoformat(), "referrals": fetch_triage_view()}


# Entry point for Lambda.
handler = Mangum(app)
