output "integration_id" {
  description = "Clara integration id."
  value       = clara_aws_integration.this.id
}

output "status" {
  description = "Integration status when it was created: active, validating or awaiting_customer_setup. Not refreshed."
  value       = clara_aws_integration.this.status
}

output "verification_state" {
  description = "Result of Clara's access check at creation: verified, partial, failed or unavailable. Not refreshed."
  value       = clara_aws_integration.this.verification_state
}

output "failed_checks" {
  description = "Permission checks that failed at creation. Empty when everything passed."
  value       = clara_aws_integration.this.failed_checks
}
