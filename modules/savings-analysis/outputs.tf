# Everything the Clara registration needs. The clara_aws_integration provider
# (phase 1 of the implementation) reads these values.

output "role_arn" {
  description = "Integration role ARN. Register with Clara as the Role ARN."
  value       = aws_iam_role.integration.arn
  depends_on  = [time_sleep.iam_propagation]
}

output "role_name" {
  description = "Integration role name."
  value       = aws_iam_role.integration.name
}

output "external_id" {
  description = "ExternalId in the trust policy. Register with Clara."
  value       = var.external_id
  sensitive   = true
}

output "permission_mode" {
  description = "minimal or full."
  value       = var.permission_mode
}

output "cur_bucket_name" {
  description = "CUR delivery bucket."
  value       = aws_s3_bucket.cur.id
}

output "cur_report_name" {
  description = "Legacy CUR report name, or null when not created."
  value       = var.create_legacy_cur ? local.cur_report_name : null
}

output "cur_s3_prefix" {
  description = "Legacy CUR S3 prefix."
  value       = var.cur_s3_prefix
}

output "cur2_export_arn" {
  description = "CUR 2.0 export ARN, or null when not created."
  value       = var.create_cur2 ? aws_bcmdataexports_export.cur2[0].arn : null
}

output "cur2_export_name" {
  description = "CUR 2.0 export name, or null when not created."
  value       = var.create_cur2 ? local.cur2_export_name : null
}

output "cur2_s3_prefix" {
  description = "CUR 2.0 S3 prefix, or null when not created."
  value       = var.create_cur2 ? var.cur2_s3_prefix : null
}

output "policy_arns" {
  description = "Customer-managed policy ARNs attached to the integration role."
  value = compact(concat(
    [aws_iam_policy.bucket.arn],
    aws_iam_policy.minimum[*].arn,
    aws_iam_policy.full[*].arn,
    aws_iam_policy.full_deny_1[*].arn,
    aws_iam_policy.full_deny_2[*].arn,
    aws_iam_policy.full_s3_data_deny[*].arn,
  ))
}
