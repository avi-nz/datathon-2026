output "bucket_name" {
  value = aws_s3_bucket.site.id
}

output "bucket_arn" {
  value = aws_s3_bucket.site.arn
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.site.id
}

output "cloudfront_url" {
  value = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "snowflake_database" {
  value = snowflake_database.main.name
}

output "snowflake_warehouse" {
  value = snowflake_warehouse.main.name
}

output "referral_intake_bucket" {
  value = aws_s3_bucket.referral_intake.id
}

output "referral_format_stages" {
  value = { for k, s in snowflake_stage_external_s3.referral_format : k => s.fully_qualified_name }
}

output "output_ui_database" {
  value = snowflake_database.output_ui.name
}

output "referral_api_url" {
  value = "https://${aws_cloudfront_distribution.site.domain_name}/referrals"
}
