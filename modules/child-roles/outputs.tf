output "child_role_name" {
  description = "Child role name deployed to member accounts."
  value       = var.permission_mode == "full" ? "nops-sa-child-role" : "nops-sa-child-role-minimal"
}

output "stack_set_name" {
  description = "StackSet that deploys the child role."
  value       = aws_cloudformation_stack_set.child.name
}
