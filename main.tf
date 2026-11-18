# Feature guards. A failed precondition stops the plan with the message.
resource "terraform_data" "feature_guard" {
  lifecycle {
    precondition {
      condition     = var.enable_savings_analysis || var.enable_child_roles || var.enable_commitment_management
      error_message = "Enable at least one feature: enable_savings_analysis, enable_child_roles or enable_commitment_management."
    }
    precondition {
      condition     = !var.enable_child_roles || var.enable_savings_analysis
      error_message = "enable_child_roles requires enable_savings_analysis: child roles trust the payer role that Savings Analysis creates."
    }
    precondition {
      condition     = !var.enable_commitment_management || var.enable_savings_analysis
      error_message = "enable_commitment_management requires enable_savings_analysis: Clara enables Commitment Management only on an active AWS integration."
    }
    precondition {
      condition     = !(var.enable_child_roles || var.enable_commitment_management) || length(var.organizational_unit_ids) > 0
      error_message = "Child roles and Commitment Management deploy StackSets: set organizational_unit_ids."
    }
  }
}

# Generated only when the caller does not supply an ExternalId.
resource "random_uuid" "external_id" {
  count = var.external_id == null ? 1 : 0
}

resource "random_uuid" "commitment_external_id" {
  count = var.commitment_external_id == null ? 1 : 0
}

resource "random_uuid" "sharesave_external_id" {
  count = var.sharesave_external_id == null ? 1 : 0
}

locals {
  external_id            = var.external_id != null ? var.external_id : one(random_uuid.external_id[*].result)
  commitment_external_id = var.commitment_external_id != null ? var.commitment_external_id : one(random_uuid.commitment_external_id[*].result)
  sharesave_external_id  = var.sharesave_external_id != null ? var.sharesave_external_id : one(random_uuid.sharesave_external_id[*].result)
}

module "savings_analysis" {
  source = "./modules/savings-analysis"
  count  = var.enable_savings_analysis ? 1 : 0

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  client_id                    = var.client_id
  data_connector_principal_arn = var.data_connector_principal_arn
  external_id                  = local.external_id
  permission_mode              = var.permission_mode
  cur_bucket_name              = var.cur_bucket_name
  create_cur_bucket            = var.create_cur_bucket
  create_legacy_cur            = var.create_legacy_cur
  cur_report_name              = var.cur_report_name
  cur_s3_prefix                = var.cur_s3_prefix
  create_cur2                  = var.create_cur2
  cur2_export_name             = var.cur2_export_name
  cur2_s3_prefix               = var.cur2_s3_prefix
  tags                         = var.tags
}

module "child_roles" {
  source = "./modules/child-roles"
  count  = var.enable_child_roles && var.enable_savings_analysis ? 1 : 0

  payer_role_arn          = module.savings_analysis[0].role_arn
  permission_mode         = var.permission_mode
  organizational_unit_ids = var.organizational_unit_ids
  tags                    = var.tags

  depends_on = [terraform_data.feature_guard]
}

module "commitment_management" {
  source = "./modules/commitment-management"
  count  = var.enable_commitment_management && var.enable_savings_analysis ? 1 : 0

  providers = {
    aws           = aws
    aws.sharesave = aws.sharesave
  }

  external_id                    = local.commitment_external_id
  sharesave_external_id          = local.sharesave_external_id
  cm_bridge_principal_arn        = var.cm_bridge_principal_arn
  sharesave_bridge_principal_arn = var.sharesave_bridge_principal_arn
  sharesave_template             = var.sharesave_template
  console_access_account_id      = var.console_access_account_id
  organizational_unit_ids        = var.organizational_unit_ids
  tags                           = var.tags

  depends_on = [terraform_data.feature_guard]
}
