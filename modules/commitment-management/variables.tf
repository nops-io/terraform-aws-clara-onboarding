variable "external_id" {
  type        = string
  sensitive   = true
  description = "ExternalId for the central role trust (NopsCMCrossAccountAssume)."

  validation {
    condition     = length(var.external_id) >= 8
    error_message = "external_id must be at least 8 characters."
  }
}

variable "sharesave_external_id" {
  type        = string
  sensitive   = true
  description = "ExternalId for the ShareSave role trust. May differ from external_id."

  validation {
    condition     = length(var.sharesave_external_id) >= 8
    error_message = "sharesave_external_id must be at least 8 characters."
  }
}

variable "cm_bridge_principal_arn" {
  type        = string
  description = "Clara role that assumes the central role. Production default."
  default     = "arn:aws:iam::861341088565:role/NopsCMCentralClientAccountAssume"

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", var.cm_bridge_principal_arn))
    error_message = "cm_bridge_principal_arn must be an IAM role ARN."
  }
}

variable "sharesave_bridge_principal_arn" {
  type        = string
  description = "Clara role that assumes the ShareSave role. Production default."
  default     = "arn:aws:iam::861341088565:role/CrossAccountSharesaveMgt"

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", var.sharesave_bridge_principal_arn))
    error_message = "sharesave_bridge_principal_arn must be an IAM role ARN."
  }
}

variable "organizational_unit_ids" {
  type        = list(string)
  description = "Organization root id or OU ids for the child read role StackSet. The payer account is never a target."

  validation {
    condition     = length(var.organizational_unit_ids) > 0
    error_message = "At least one organizational unit id or the root id is required."
  }
}

variable "stack_set_region" {
  type        = string
  description = "Region for the child StackSet instances. IAM is global, so one region is enough."
  default     = "us-east-1"
}

variable "tags" {
  type        = map(string)
  description = "Tags for the stacks and the StackSet."
  default     = {}
}
