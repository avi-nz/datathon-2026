# UoA Data Science Club x dataengine Datathon 2026

# COMPETITION RESULT:

#### 1st Place
#### Fast track interview with dataengine

----

## Problem
Healthcare providers receive referrals from multiple channels
and need to assess urgency, service eligibility, location,
workforce availability and follow-up requirements. This
process is often manual, time-sensitive and dependent on
information spread across different systems, which can lead
to delays, inconsistent prioritisation and limited visibility of
workload

## Our challenge
Design an AI-assisted workflow that classifies and prioritises
incoming healthcare referrals, then identifies where
automation could support routine next steps, such as routing,
status updates, follow-up reminders or escalation.

## Expected outcomes
Teams should:
* Design a healthcare referral coordination data model
* Build a pipeline for referral, client, service, location and
workforce data
* Use AI to classify, summarise or prioritise referrals
* Produce a triage score, risk flag or prioritisation method
* Identify where robotic or workflow automation could reduce
manual effort
* Present recommendations through a dashboard, workflow view
or analytical output

## What success looks like
A healthcare coordinator can quickly understand which referrals
need attention first, why they have been prioritised, and what
action should happen next. The use case demonstrates how data,
AI and automation can support faster, more consistent healthcare
coordination while keeping human oversight in the process.

----

GP referral triage: GP portals submit referrals to S3, Snowflake loads and standardises them,
a batch pipeline classifies urgency (Jev) and writes a justification (Claude Haiku on Bedrock),
and a dashboard shows the results via an API on Lambda behind CloudFront.

```
frontend/                 Static site, synced to the website S3 bucket (folder root = site root)
  index.html              Triage dashboard (reads GET /referrals)
  interface1.html         GP portal, Format A (POST /interface1/upload)
  interface2.html         GP portal, Format B, legacy style (POST /interface2/upload)
  css/, js/

backend/
  api/                    FastAPI app on Lambda: GET /referrals, POST /interfaceN/upload
  pipeline/               Batch job: Jev urgency + Claude justification -> AI_REFERRAL_RESULTS
  common/                 Snowflake connection and triage view query, shared by both
  sample_data/            Synthetic Format A/B referrals and example GP notes
  .env.example            Settings for the pipeline and local API (copy to .env)

infrastructure/
  terraform/              AWS (S3, CloudFront, Lambda) and Snowflake (databases, tables,
                          view, S3 intake task, roles). See terraform/README.md
  snowflake/              manual_setup.sql: the service user Terraform doesn't create
```

## Running

Pipeline (processes referrals that don't have an AI result yet):

```sh
cd backend
uv run --with-requirements pipeline/requirements.txt python -m pipeline.main
```

API locally:

```sh
cd backend
uv run --with-requirements api/requirements.txt --with uvicorn uvicorn api.app:app
```

## Deploying

Infrastructure, including building and deploying the API Lambda:

```sh
cd infrastructure/terraform
set -a; source .env; set +a
terraform plan
terraform apply
```

Frontend (bucket and distribution IDs come from `terraform output`):

```sh
aws s3 sync frontend/ s3://<bucket_name> --delete
aws cloudfront create-invalidation --distribution-id <cloudfront_distribution_id> --paths '/*'
```

## Screenshot of coordinator user interface
<img width="799" height="875" alt="Screenshot 2026-09-26 at 00 30 00" src="https://github.com/user-attachments/assets/8a3db556-b67f-4871-93bb-5dfc44bc7699" />
