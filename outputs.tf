output "role_arn" {
  description = "Integration role ARN, or null when Savings Analysis is disabled."
  value       = one(module.savings_analysis[*].role_arn)
}

output "role_name" {
  description = "Integration role name, or null when Savings Analysis is disabled."
  value       = one(module.savings_analysis[*].role_name)
}

output "external_id" {
  description = "ExternalId in the trust policy. Sensitive. Register it with Clara."
  value       = local.external_id
  sensitive   = true
}

output "permission_mode" {
  description = "minimal or full."
  value       = var.permission_mode
}

output "cur_bucket_name" {
  description = "CUR delivery bucket, or null when Savings Analysis is disabled."
  value       = one(module.savings_analysis[*].cur_bucket_name)
}

output "cur_report_name" {
  description = "Legacy CUR report name, or null."
  value       = one(module.savings_analysis[*].cur_report_name)
}

output "cur2_export_arn" {
  description = "CUR 2.0 export ARN, or null."
  value       = one(module.savings_analysis[*].cur2_export_arn)
}

output "child_role_name" {
  description = "Child role deployed to member accounts, or null when child roles are disabled."
  value       = one(module.child_roles[*].child_role_name)
}

output "registration" {
  description = "Everything the Clara registration needs, in one object. Sensitive (contains the ExternalId)."
  sensitive   = true
  value = var.enable_savings_analysis ? {
    role_arn        = one(module.savings_analysis[*].role_arn)
    external_id     = local.external_id
    permission_mode = var.permission_mode
    cur_bucket_name = one(module.savings_analysis[*].cur_bucket_name)
    cur_report_name = one(module.savings_analysis[*].cur_report_name)
    cur2_export_arn = one(module.savings_analysis[*].cur2_export_arn)
    child_role_name = one(module.child_roles[*].child_role_name)
  } : null
}
