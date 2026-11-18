output "central_role_arn" {
  description = "NopsCMCrossAccountAssume ARN. Register with Clara."
  value       = aws_cloudformation_stack.central.outputs["RoleArn"]
}

output "payer_read_role_arn" {
  description = "NopsCMReadEC2Instances ARN in the payer account."
  value       = aws_cloudformation_stack.payer_read.outputs["RoleArn"]
}

output "child_stack_set_name" {
  description = "StackSet that deploys NopsCMReadEC2Instances to member accounts."
  value       = aws_cloudformation_stack_set.child.name
}

output "sharesave_role_arn" {
  description = "nops-sharesave-mgt ARN. Register with Clara."
  value       = aws_cloudformation_stack.sharesave.outputs[var.sharesave_template == "dual" ? "ApiRoleArn" : "RoleArn"]
}

output "sharesave_console_role_arn" {
  description = "nops-sharesave-mgt-console ARN, for Switch Role. Null with sharesave_template = single."
  value       = var.sharesave_template == "dual" ? aws_cloudformation_stack.sharesave.outputs["ConsoleRoleArn"] : null
}
