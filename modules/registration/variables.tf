variable "payer_account_id" {
  type        = string
  description = "12-digit payer (management) account id that the root module was applied in."

  validation {
    condition     = can(regex("^[0-9]{12}$", var.payer_account_id))
    error_message = "payer_account_id must be a 12-digit AWS account id."
  }
}

variable "registration" {
  type = object({
    role_arn         = string
    external_id      = string
    permission_mode  = string
    cur_bucket_name  = string
    cur_report_name  = optional(string)
    cur_s3_prefix    = optional(string)
    cur2_export_name = optional(string)
    cur2_s3_prefix   = optional(string)
  })
  sensitive   = true
  description = "The registration output of the clara-onboarding root module. Extra attributes in that output are ignored."

  validation {
    condition     = var.registration != null
    error_message = "registration is null. Enable Savings Analysis in the root module (enable_savings_analysis = true)."
  }
}

variable "name" {
  type        = string
  description = "Name shown in Clara. Empty means \"AWS Account <payer account id>\"."
  default     = null
}

variable "wait_for_verification" {
  type        = bool
  description = "Run Clara's access verification and fail unless the integration becomes active."
  default     = true
}

variable "verification_timeout_seconds" {
  type        = number
  description = "How long to wait for verification."
  default     = 300
}
