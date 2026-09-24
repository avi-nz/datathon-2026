# Referral API: a FastAPI app (backend/app.py) on Lambda that returns
# OUTPUT_UI.PUBLIC.REFERRAL_TRIAGE_VIEW as JSON at GET <function URL>/referrals.
# Terraform builds the package too: pip-installs the dependencies with uv, then zips them.

locals {
  repo_root   = "${path.module}/.."
  api_build   = "${local.repo_root}/backend/build"
  api_sources = ["backend/requirements.txt", "backend/app.py", "db.py", "export_ui.py"]
}

# Rebuilds backend/build whenever the app code or its requirements change.
# Wheels are fetched for Linux arm64 / Python 3.12 (the Lambda runtime), not for this machine.
resource "terraform_data" "referral_api_build" {
  triggers_replace = { for f in local.api_sources : f => filesha256("${local.repo_root}/${f}") }

  provisioner "local-exec" {
    working_dir = local.repo_root
    command     = <<-EOT
      set -e
      rm -rf backend/build
      uv pip install -r backend/requirements.txt --target backend/build \
        --python-platform aarch64-manylinux2014 --python-version 3.12 --only-binary :all:
      cp backend/app.py db.py export_ui.py backend/build/
    EOT
  }
}

# depends_on makes this read only after the build above has run.
data "archive_file" "referral_api" {
  type        = "zip"
  source_dir  = local.api_build
  output_path = "${local.repo_root}/backend/dist/lambda.zip"

  depends_on = [terraform_data.referral_api_build]
}

data "aws_iam_policy_document" "lambda_assume" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "referral_api" {
  name               = "${var.project_name}-${var.environment}-referral-api"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume.json
}

# Lets the function write its logs to CloudWatch.
resource "aws_iam_role_policy_attachment" "referral_api_logs" {
  role       = aws_iam_role.referral_api.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "referral_api" {
  function_name    = "${var.project_name}-${var.environment}-referral-api"
  role             = aws_iam_role.referral_api.arn
  runtime          = "python3.12"
  architectures    = ["arm64"]
  handler          = "app.handler"
  memory_size      = 512
  timeout          = 30
  filename         = data.archive_file.referral_api.output_path
  source_code_hash = data.archive_file.referral_api.output_base64sha256

  environment {
    variables = {
      SNOWFLAKE_ACCOUNT   = var.snowflake_api_account
      SNOWFLAKE_USER      = var.snowflake_api_user
      SNOWFLAKE_PASSWORD  = var.snowflake_api_password
      SNOWFLAKE_WAREHOUSE = var.snowflake_api_warehouse
      # The Snowflake connector writes cache files under $HOME; only /tmp is writable on Lambda.
      HOME = "/tmp"
    }
  }
}

# A public HTTPS URL for the function, no API Gateway needed.
resource "aws_lambda_function_url" "referral_api" {
  function_name      = aws_lambda_function.referral_api.function_name
  authorization_type = "NONE"

  cors {
    allow_origins = ["*"]
    allow_methods = ["GET"]
  }
}
