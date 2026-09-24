# S3 -> Snowflake path for incoming referrals:
#   JSON files land in s3://<bucket>/format-a/ or format-b/ -> the storage integration
#   lets Snowflake read the bucket -> one external stage per folder -> a scheduled task
#   COPYs new files into RAW_FORMAT_A/B_REFERRALS, then parses the new rows into
#   STANDARDIZED_REFERRALS.

locals {
  referral_intake_role_name = "${var.project_name}-${var.environment}-snowflake-referral-intake"
  # Built from strings (not from aws_iam_role) so the integration and the role
  # don't depend on each other in a loop.
  referral_intake_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.referral_intake_role_name}"
}

# ---------- AWS: the bucket where all referral files land ----------

resource "aws_s3_bucket" "referral_intake" {
  bucket = "${var.project_name}-${var.environment}-referral-intake-${data.aws_caller_identity.current.account_id}"
}

resource "aws_s3_bucket_public_access_block" "referral_intake" {
  bucket = aws_s3_bucket.referral_intake.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

data "aws_iam_policy_document" "referral_intake_bucket" {
  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.referral_intake.arn, "${aws_s3_bucket.referral_intake.arn}/*"]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "referral_intake" {
  bucket = aws_s3_bucket.referral_intake.id
  policy = data.aws_iam_policy_document.referral_intake_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.referral_intake]
}

# ---------- Snowflake <-> AWS trust ----------

# A storage integration lets Snowflake assume an AWS IAM role, so no AWS keys are
# stored in Snowflake. Snowflake creates its own IAM user plus an external ID,
# and the role below trusts only that pair.
resource "snowflake_storage_integration_aws" "referral_intake" {
  name                      = "REFERRAL_INTAKE_INTEGRATION"
  enabled                   = true
  storage_provider          = "S3"
  storage_aws_role_arn      = local.referral_intake_role_arn
  storage_allowed_locations = ["s3://${aws_s3_bucket.referral_intake.id}/"]
}

data "aws_iam_policy_document" "snowflake_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [snowflake_storage_integration_aws.referral_intake.describe_output[0].iam_user_arn]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [snowflake_storage_integration_aws.referral_intake.describe_output[0].external_id]
    }
  }
}

data "aws_iam_policy_document" "snowflake_read_intake" {
  statement {
    actions   = ["s3:GetObject", "s3:GetObjectVersion"]
    resources = ["${aws_s3_bucket.referral_intake.arn}/*"]
  }

  statement {
    actions   = ["s3:ListBucket", "s3:GetBucketLocation"]
    resources = [aws_s3_bucket.referral_intake.arn]
  }
}

resource "aws_iam_role" "snowflake_referral_intake" {
  name               = local.referral_intake_role_name
  assume_role_policy = data.aws_iam_policy_document.snowflake_assume.json
}

resource "aws_iam_role_policy" "snowflake_read_intake" {
  role   = aws_iam_role.snowflake_referral_intake.id
  policy = data.aws_iam_policy_document.snowflake_read_intake.json
}

# ---------- Snowflake: stages, streams + scheduled load/standardize ----------

# An external stage is a named pointer to an S3 location. `LIST @FORMAT_A_S3_STAGE`
# shows the files, and COPY INTO reads them using the JSON format attached here.
# One per folder, because the two referral formats land in different tables.
resource "snowflake_stage_external_s3" "referral_format" {
  for_each = { A = "format-a", B = "format-b" }

  database            = snowflake_database.main.name
  schema              = local.schema
  name                = "FORMAT_${each.key}_S3_STAGE"
  url                 = "s3://${aws_s3_bucket.referral_intake.id}/${each.value}/"
  storage_integration = snowflake_storage_integration_aws.referral_intake.name

  file_format {
    format_name = snowflake_file_format_json.json_standard.fully_qualified_name
  }

  depends_on = [
    aws_iam_role_policy.snowflake_read_intake,
  ]
}

# A stream is a bookmark on a table: selecting from it returns only rows added
# since it was last consumed, and using it in an INSERT moves the bookmark forward.
# This way each raw row is standardized exactly once, however often the task runs.
resource "snowflake_stream_on_table" "raw_format" {
  for_each = toset(["A", "B"])

  database = snowflake_database.main.name
  schema   = local.schema
  name     = "RAW_FORMAT_${each.key}_STREAM"
  table    = snowflake_table.this["RAW_FORMAT_${each.key}_REFERRALS"].fully_qualified_name
}

# A task runs SQL on a schedule using the given warehouse. The body is a Snowflake
# Scripting block (BEGIN ... END) so it can run several statements in order:
#   1. COPY new files from S3 into the raw tables. COPY keeps 64 days of load
#      history per table, so files already loaded are skipped.
#   2. Parse the new raw rows (read from the streams) into STANDARDIZED_REFERRALS,
#      with one parser per source format.
resource "snowflake_task" "process_referrals" {
  database  = snowflake_database.main.name
  schema    = local.schema
  name      = "PROCESS_REFERRALS_TASK"
  warehouse = snowflake_warehouse.main.name
  started   = true

  schedule {
    minutes = var.referral_load_schedule_minutes
  }

  sql_statement = <<-SQL
    EXECUTE IMMEDIATE $$
    BEGIN
      COPY INTO ${local.fq}.RAW_FORMAT_A_REFERRALS (raw)
        FROM @${snowflake_stage_external_s3.referral_format["A"].fully_qualified_name}
        ON_ERROR = 'CONTINUE';
      COPY INTO ${local.fq}.RAW_FORMAT_B_REFERRALS (raw)
        FROM @${snowflake_stage_external_s3.referral_format["B"].fully_qualified_name}
        ON_ERROR = 'CONTINUE';

      -- Parser A: flat JSON, ISO timestamp
      INSERT INTO ${local.fq}.STANDARDIZED_REFERRALS
          (referral_id, nhi_number, reason_text, patient_age, existing_conditions,
           risk_history, facility_id, submitting_gp_id, submitted_at, source_format)
      SELECT
          UUID_STRING(),
          raw:nhi_number::VARCHAR,
          raw:gp_notes::VARCHAR,
          raw:age::INT,
          raw:existing_conditions::VARCHAR,
          raw:risk_history::VARCHAR,
          raw:facility_id::VARCHAR,
          raw:submitting_gp_id::VARCHAR,
          TRY_TO_TIMESTAMP(raw:submitted_at::VARCHAR),
          'gp_form'
      FROM ${snowflake_stream_on_table.raw_format["A"].fully_qualified_name};

      -- Parser B: nested JSON, DD-MM-YYYY HH:MM timestamp
      INSERT INTO ${local.fq}.STANDARDIZED_REFERRALS
          (referral_id, nhi_number, reason_text, patient_age, existing_conditions,
           risk_history, facility_id, submitting_gp_id, submitted_at, source_format)
      SELECT
          UUID_STRING(),
          raw:patient.identifier::VARCHAR,
          raw:referral.clinicalNotes::VARCHAR,
          raw:patient.demographics.age::INT,
          raw:patient.clinicalHistory.conditions::VARCHAR,
          raw:patient.clinicalHistory.riskNotes::VARCHAR,
          raw:referral.facility::VARCHAR,
          raw:referral.referringGp::VARCHAR,
          TRY_TO_TIMESTAMP(raw:referral.timestamp::VARCHAR, 'DD-MM-YYYY HH24:MI'),
          'referral_letter'
      FROM ${snowflake_stream_on_table.raw_format["B"].fully_qualified_name};
    END;
    $$
  SQL

  depends_on = [
    snowflake_table.this,
  ]
}
