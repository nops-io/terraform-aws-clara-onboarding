locals {
  is_full = var.permission_mode == "full"

  integration_role_name = "nops-integration-role-${var.client_id}"
  cur_report_name       = var.cur_report_name != "" ? var.cur_report_name : "nops_cur_${var.client_id}_hourly"
  cur2_export_name      = var.cur2_export_name != "" ? var.cur2_export_name : "nops_cur2_${var.client_id}_hourly"

  account_id = data.aws_caller_identity.current.account_id
  bucket_arn = "arn:aws:s3:::${var.cur_bucket_name}"

  # Minimum and Full allow/deny documents are vendored from Clara's policy documents, the
  # same ones its CloudFormation templates use. Only the CUR bucket placeholder in the S3 data
  # deny is filled in here, the same way the CloudFormation template does it.
  s3_data_deny_source = jsondecode(file("${path.module}/policies/full-s3-data-deny.json"))
  s3_data_deny_policy = jsonencode({
    Version = local.s3_data_deny_source.Version
    Statement = [
      merge(local.s3_data_deny_source.Statement[0], {
        NotResource = [
          "${local.bucket_arn}/*",
          "arn:aws:s3:::*/nops-cur2/*",
        ]
      })
    ]
  })

  cur2_query = trimspace(file("${path.module}/cur2/query.sql"))
}
