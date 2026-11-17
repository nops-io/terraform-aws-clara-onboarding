output "role_arn" {
  description = "Savings Analysis integration role ARN, or null."
  value       = one(module.savings_analysis[*].role_arn)
}

output "role_name" {
  description = "Savings Analysis integration role name, or null."
  value       = one(module.savings_analysis[*].role_name)
}

output "external_id" {
  description = "Savings Analysis ExternalId. Sensitive. Register it with Clara."
  value       = local.external_id
  sensitive   = true
}

output "permission_mode" {
  description = "minimal or full."
  value       = var.permission_mode
}

output "cur_bucket_name" {
  description = "CUR delivery bucket, or null."
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
  description = "Savings Analysis child role name, or null."
  value       = one(module.child_roles[*].child_role_name)
}

output "commitment_central_role_arn" {
  description = "Commitment Management central role ARN, or null."
  value       = one(module.commitment_management[*].central_role_arn)
}

output "commitment_sharesave_role_arn" {
  description = "ShareSave role ARN, or null."
  value       = one(module.commitment_management[*].sharesave_role_arn)
}

output "registration" {
  description = "Everything the Clara registration needs, in one object. Sensitive (contains the ExternalIds)."
  sensitive   = true
  value = var.enable_savings_analysis ? {
    role_arn               = one(module.savings_analysis[*].role_arn)
    external_id            = local.external_id
    permission_mode        = var.permission_mode
    cur_bucket_name        = one(module.savings_analysis[*].cur_bucket_name)
    cur_report_name        = one(module.savings_analysis[*].cur_report_name)
    cur2_export_arn        = one(module.savings_analysis[*].cur2_export_arn)
    child_role_name        = one(module.child_roles[*].child_role_name)
    commitment_enabled     = var.enable_commitment_management
    commitment_central_arn = one(module.commitment_management[*].central_role_arn)
    commitment_external_id = var.enable_commitment_management ? local.commitment_external_id : null
    sharesave_role_arn     = one(module.commitment_management[*].sharesave_role_arn)
    sharesave_external_id  = var.enable_commitment_management ? local.sharesave_external_id : null
  } : null
}
