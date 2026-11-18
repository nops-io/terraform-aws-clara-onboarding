output "integration_id" {
  description = "Clara integration id."
  value       = clara_aws_integration.this.id
}

output "status" {
  description = "Integration status in Clara, for example active."
  value       = clara_aws_integration.this.status
}
