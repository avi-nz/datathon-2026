"""
Serves the referral triage view as JSON, for the web UI.

GET /referrals returns every row of OUTPUT_UI.PUBLIC.REFERRAL_TRIAGE_VIEW: each standardised GP
referral joined to its AI result (null AI fields until main.py has processed it). Same shape as
the data common/triage_view.py returns: { generated_at: "<ISO timestamp>", referrals: [ {...}, ... ] }.

POST /interface1/upload and /interface2/upload save a referral submitted from the GP portal pages
(frontend/interface1.html, frontend/interface2.html) as a JSON file in the S3 intake bucket, where Snowflake's
PROCESS_REFERRALS_TASK picks it up.

Runs on AWS Lambda through Mangum (see infrastructure/terraform/lambda.tf). Run it locally from backend/ with:
    uv run --with-requirements api/requirements.txt --with uvicorn uvicorn api.app:app
"""

import json
import os
import uuid
from datetime import datetime, timezone

from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from mangum import Mangum

from common.triage_view import fetch_triage_view

app = FastAPI()
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["GET"])


@app.get("/referrals")
def list_referrals():
    return {"generated_at": datetime.now(timezone.utc).isoformat(), "referrals": fetch_triage_view()}


# Intake bucket folder for each portal: interface1 sends Format A JSON, interface2 Format B.
UPLOAD_FOLDERS = {"interface1": "format-a", "interface2": "format-b"}


@app.post("/{interface}/upload")
async def upload_referral(interface: str, request: Request):
    folder = UPLOAD_FOLDERS.get(interface)
    if folder is None:
        raise HTTPException(status_code=404, detail="Unknown interface")
    referral = await request.json()
    key = f"{folder}/{uuid.uuid4()}.json"
    # Imported here because boto3 ships with the Lambda runtime but isn't in requirements.txt,
    # so running the app locally for GET /referrals doesn't need it.
    import boto3

    boto3.client("s3").put_object(
        Bucket=os.environ["INTAKE_BUCKET"],
        Key=key,
        Body=json.dumps(referral),
        ContentType="application/json",
    )
    return {"message": "Referral uploaded", "key": key}


# Entry point for Lambda.
handler = Mangum(app)
