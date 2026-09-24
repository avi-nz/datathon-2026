# Referral API: a FastAPI app (backend/api/app.py) on Lambda that returns
# OUTPUT_UI.PUBLIC.REFERRAL_TRIAGE_VIEW as JSON at GET https://<website CloudFront>/referrals,
# and saves GP portal submissions (POST /interface1/upload, /interface2/upload) to S3.
# Terraform builds the package too: pip-installs the dependencies with uv, then zips them.

locals {
  backend_dir = "${path.module}/../../backend"
  api_build   = "${local.backend_dir}/build"
  # Relative to backend/. The api and common packages are copied into the package as-is.
  api_sources = [
    "api/requirements.txt", "api/__init__.py", "api/app.py",
    "common/__init__.py", "common/db.py", "common/triage_view.py",
  ]
}

# Rebuilds backend/build whenever the app code or its requirements change.
# Wheels are fetched for Linux arm64 / Python 3.12 (the Lambda runtime), not for this machine.
resource "terraform_data" "referral_api_build" {
  triggers_replace = { for f in local.api_sources : f => filesha256("${local.backend_dir}/${f}") }

  provisioner "local-exec" {
    working_dir = local.backend_dir
    command     = <<-EOT
      set -e
      rm -rf build
      uv pip install -r api/requirements.txt --target build \
        --python-platform aarch64-manylinux2014 --python-version 3.12 --only-binary :all:
      mkdir -p build/api build/common
      cp api/__init__.py api/app.py build/api/
      cp common/__init__.py common/db.py common/triage_view.py build/common/
    EOT
  }
}

# depends_on makes this read only after the build above has run.
data "archive_file" "referral_api" {
  type        = "zip"
  source_dir  = local.api_build
  output_path = "${local.backend_dir}/dist/lambda.zip"

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
  handler          = "api.app.handler"
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
      INTAKE_BUCKET       = var.intake_upload_bucket
      # The Snowflake connector writes cache files under $HOME; only /tmp is writable on Lambda.
      HOME = "/tmp"
    }
  }
}

# Lets the function save GP portal submissions into the intake bucket.
resource "aws_iam_role_policy" "referral_api_upload" {
  role = aws_iam_role.referral_api.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "s3:PutObject"
      Resource = "arn:aws:s3:::${var.intake_upload_bucket}/*"
    }]
  })
}

# HTTPS URL for the function. AWS_IAM auth means only signed requests get through:
# the website CloudFront distribution (cloudfront.tf) serves it at /referrals and signs
# each request with the origin access control below. Direct calls get a 403.
resource "aws_lambda_function_url" "referral_api" {
  function_name      = aws_lambda_function.referral_api.function_name
  authorization_type = "AWS_IAM"
}

locals {
  # https://<id>.lambda-url.<region>.on.aws/ -> <id>.lambda-url.<region>.on.aws, the CloudFront origin.
  referral_api_domain = trimsuffix(trimprefix(aws_lambda_function_url.referral_api.function_url, "https://"), "/")
}

resource "aws_cloudfront_origin_access_control" "referral_api" {
  name                              = "${var.project_name}-${var.environment}-referral-api"
  origin_access_control_origin_type = "lambda"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront needs both permissions to call a function URL, and only this distribution gets them.
resource "aws_lambda_permission" "referral_api_cloudfront_url" {
  statement_id           = "AllowCloudFrontInvokeFunctionUrl"
  action                 = "lambda:InvokeFunctionUrl"
  function_name          = aws_lambda_function.referral_api.function_name
  principal              = "cloudfront.amazonaws.com"
  source_arn             = aws_cloudfront_distribution.site.arn
  function_url_auth_type = "AWS_IAM"
}

resource "aws_lambda_permission" "referral_api_cloudfront_invoke" {
  statement_id             = "AllowCloudFrontInvokeFunction"
  action                   = "lambda:InvokeFunction"
  function_name            = aws_lambda_function.referral_api.function_name
  principal                = "cloudfront.amazonaws.com"
  source_arn               = aws_cloudfront_distribution.site.arn
  invoked_via_function_url = true
}
