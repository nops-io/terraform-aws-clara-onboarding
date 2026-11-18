# Registers the AWS resources created by the root module with Clara, through the
# Clara API. Needs a Clara API key in CLARA_API_KEY (see the clara provider).
#
# This module is optional. The root module works without it: without a key, the
# customer pastes the role ARN into Clara's setup wizard instead.
resource "clara_aws_integration" "this" {
  payer_account_id = var.payer_account_id
  name             = var.name

  permission_mode = var.registration.permission_mode
  role_arn        = var.registration.role_arn
  external_id     = var.registration.external_id

  cur_bucket_name  = var.registration.cur_bucket_name
  cur_report_name  = var.registration.cur_report_name
  cur_s3_prefix    = var.registration.cur_s3_prefix
  cur2_export_name = var.registration.cur2_export_name
  cur2_s3_prefix   = var.registration.cur2_s3_prefix

  wait_for_verification        = var.wait_for_verification
  verification_timeout_seconds = var.verification_timeout_seconds
}
