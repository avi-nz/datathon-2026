# Infrastructure handoff

What Terraform in this folder manages, as of 2026-09-24 (47 resources in state).

## Snowflake

| Area | What's managed | File |
|---|---|---|
| Databases | `REFERRAL_TRIAGE`, `OUTPUT_UI` | `snowflake.tf` |
| Warehouse | `COMPUTE_WH` (XSMALL, suspends after 60s idle) | `snowflake.tf` |
| Tables | `RAW_FORMAT_A_REFERRALS`, `RAW_FORMAT_B_REFERRALS`, `STANDARDIZED_REFERRALS`, `AI_REFERRAL_RESULTS` | `snowflake_tables.tf` |
| View | `REFERRAL_TRIAGE_VIEW` | `snowflake_views.tf` |
| File format | `JSON_STANDARD` | `snowflake_stages.tf` |
| S3 link | `REFERRAL_INTAKE_INTEGRATION`, `FORMAT_A_S3_STAGE`, `FORMAT_B_S3_STAGE` | `referral_intake.tf` |
| Processing | `RAW_FORMAT_A_STREAM`, `RAW_FORMAT_B_STREAM`, `PROCESS_REFERRALS_TASK` (loads new files from S3 and standardizes them every 60 min) | `referral_intake.tf` |
| Roles | `ANALYST_ROLE`, `DATA_ENGINEER_ROLE`, `VIEWER_ROLE`, plus their 19 grants | `roles.tf` |

## AWS

| Area | What's managed | File |
|---|---|---|
| Referral intake | S3 bucket `datathon-2026-dev-referral-intake-…`, its policy and public-access block | `referral_intake.tf` |
| Snowflake access | IAM role and read-only policy that Snowflake assumes to read the bucket | `referral_intake.tf` |
| Website | S3 bucket, its policy and public-access block, the CloudFront distribution and its origin access control | `s3.tf`, `cloudfront.tf` |

