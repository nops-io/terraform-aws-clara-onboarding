# ---- Which features to deploy -------------------------------------------------

variable "enable_savings_analysis" {
  type        = bool
  description = "Deploy the Savings Analysis integration: payer role, policies, CUR bucket, Legacy CUR and optional CUR 2.0."
  default     = true
}

variable "enable_child_roles" {
  type        = bool
  description = "Deploy the child read role to member accounts through a service-managed StackSet. Requires enable_savings_analysis."
  default     = false
}

variable "enable_commitment_management" {
  type        = bool
  description = "Deploy Commitment Management: central role, payer read role, child read roles (StackSet) and the ShareSave role in a dedicated child account. Requires enable_savings_analysis and the aws.sharesave provider."
  default     = false
}

# ---- Clara identity ------------------------------------------------------------

variable "client_id" {
  type        = string
  description = "Clara client id. Used in the integration role name, nops-integration-role-<client_id>."

  validation {
    condition     = can(regex("^[0-9]+$", var.client_id))
    error_message = "client_id must be digits only."
  }
}

variable "data_connector_principal_arn" {
  type        = string
  description = "Clara data connector role that assumes the integration role. The default is the production value."
  default     = "arn:aws:iam::861341088565:role/nops-data-connector"

  validation {
    condition     = can(regex("^arn:aws:iam::[0-9]{12}:role/.+$", var.data_connector_principal_arn))
    error_message = "data_connector_principal_arn must be an IAM role ARN."
  }
}

variable "external_id" {
  type        = string
  description = "ExternalId for the trust policy. Leave null to generate one (random_uuid). Keep it stable: changing it breaks the trust until Clara is updated."
  default     = null
  sensitive   = true

  validation {
    condition     = var.external_id == null ? true : length(var.external_id) >= 8
    error_message = "external_id must be at least 8 characters when set."
  }
}

# ---- Savings Analysis ----------------------------------------------------------

variable "permission_mode" {
  type        = string
  description = "minimal = Savings Analysis (Minimum Platform). full = Full Platform (Inform & Operate)."
  default     = "minimal"

  validation {
    condition     = contains(["minimal", "full"], var.permission_mode)
    error_message = "permission_mode must be \"minimal\" or \"full\"."
  }
}

variable "cur_bucket_name" {
  type        = string
  description = "S3 bucket for CUR delivery. Created by this module in us-east-1. Must be globally unique."

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.cur_bucket_name))
    error_message = "cur_bucket_name must be a valid S3 bucket name."
  }
}

variable "create_legacy_cur" {
  type        = bool
  description = "Create the Legacy CUR report that Clara's Savings Analysis ingests."
  default     = true
}

variable "create_cur2" {
  type        = bool
  description = "Create the CUR 2.0 (BCM data export) in the same bucket."
  default     = false
}

variable "cur_report_name" {
  type        = string
  description = "Legacy CUR report name. Empty means nops_cur_<client_id>_hourly, the name Clara's wizard suggests."
  default     = ""

  validation {
    condition     = can(regex("^$|^[A-Za-z0-9_-]{1,128}$", var.cur_report_name))
    error_message = "cur_report_name may contain letters, digits, underscores and hyphens (up to 128 characters)."
  }
}

variable "cur_s3_prefix" {
  type        = string
  description = "S3 prefix for the Legacy CUR. Must match what you enter in the Clara wizard."
  default     = "nops-cur"

  validation {
    condition     = can(regex("^[0-9A-Za-z._/-]+$", var.cur_s3_prefix))
    error_message = "cur_s3_prefix may contain letters, digits, dots, underscores, slashes and hyphens."
  }
}

variable "cur2_export_name" {
  type        = string
  description = "CUR 2.0 export name. Empty means nops_cur2_<client_id>_hourly."
  default     = ""

  validation {
    condition     = can(regex("^$|^[A-Za-z0-9_-]{1,128}$", var.cur2_export_name))
    error_message = "cur2_export_name may contain letters, digits, underscores and hyphens (up to 128 characters)."
  }
}

variable "cur2_s3_prefix" {
  type        = string
  description = "S3 prefix for CUR 2.0. Keep nops-cur2 unless Clara is told otherwise: Full Platform's S3 data deny exempts that folder."
  default     = "nops-cur2"

  validation {
    condition     = can(regex("^[0-9A-Za-z._/-]+$", var.cur2_s3_prefix))
    error_message = "cur2_s3_prefix may contain letters, digits, dots, underscores, slashes and hyphens."
  }
}

# ---- Commitment Management -----------------------------------------------------

variable "commitment_external_id" {
  type        = string
  description = "ExternalId for the Commitment Management central role. Leave null to generate one."
  default     = null
  sensitive   = true

  validation {
    condition     = var.commitment_external_id == null ? true : length(var.commitment_external_id) >= 8
    error_message = "commitment_external_id must be at least 8 characters when set."
  }
}

variable "sharesave_external_id" {
  type        = string
  description = "ExternalId for the ShareSave role. Leave null to generate one. May differ from commitment_external_id."
  default     = null
  sensitive   = true

  validation {
    condition     = var.sharesave_external_id == null ? true : length(var.sharesave_external_id) >= 8
    error_message = "sharesave_external_id must be at least 8 characters when set."
  }
}

variable "cm_bridge_principal_arn" {
  type        = string
  description = "Clara role that assumes the Commitment Management central role. Production default."
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

# ---- Child roles ---------------------------------------------------------------

variable "organizational_unit_ids" {
  type        = list(string)
  description = "Organization root id (r-xxxx) or OU ids for the child role StackSets (Savings Analysis and Commitment Management). The payer account is never a target."
  default     = []
}

# ---- Tags ----------------------------------------------------------------------

variable "tags" {
  type        = map(string)
  description = "Tags applied to resources that support them."
  default     = {}
}
