variable "payer_role_arn" {
  type        = string
  description = "ARN of the integration role in the payer account. The only principal allowed to assume the child role."

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", var.payer_role_arn))
    error_message = "payer_role_arn must be an IAM role ARN."
  }
}

variable "permission_mode" {
  type        = string
  description = "Must match the payer role's permission mode. The child role name is nops-sa-child-role (full) or nops-sa-child-role-minimal (minimal), and a payer role can only assume its own tier."

  validation {
    condition     = contains(["minimal", "full"], var.permission_mode)
    error_message = "permission_mode must be \"minimal\" or \"full\"."
  }
}

variable "organizational_unit_ids" {
  type        = list(string)
  description = "Organization root id (r-xxxx) or OU ids to deploy to. The payer account is never a target."

  validation {
    condition     = length(var.organizational_unit_ids) > 0
    error_message = "At least one organizational unit id or the root id is required."
  }
}

variable "stack_set_name" {
  type        = string
  description = "StackSet name."
  default     = "clara-sa-child-roles"
}

variable "stack_set_region" {
  type        = string
  description = "Region for the stack instances. IAM is global, so one region is enough."
  default     = "us-east-1"
}

variable "tags" {
  type        = map(string)
  description = "Tags for the StackSet."
  default     = {}
}
