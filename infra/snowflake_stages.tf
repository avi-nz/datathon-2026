# A file format is a reusable, named set of parsing rules that COPY INTO uses to read files.
# Referral files are JSON; each top-level object becomes one row in a RAW_* table.
resource "snowflake_file_format_json" "json_standard" {
  database = snowflake_database.main.name
  schema   = local.schema
  name     = "JSON_STANDARD"
}
