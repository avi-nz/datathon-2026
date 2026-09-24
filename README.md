# datathon-2026

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
