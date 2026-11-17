# Feature guards. Each condition is checked at plan time; a failure stops the plan
# with the message below.
resource "terraform_data" "feature_guard" {
  lifecycle {
    precondition {
      condition     = var.enable_savings_analysis || var.enable_child_roles
      error_message = "Enable at least one feature: enable_savings_analysis and/or enable_child_roles."
    }
    precondition {
      condition     = !var.enable_child_roles || var.enable_savings_analysis
      error_message = "enable_child_roles requires enable_savings_analysis: child roles trust the payer role that Savings Analysis creates."
    }
    precondition {
      condition     = !var.enable_child_roles || length(var.organizational_unit_ids) > 0
      error_message = "enable_child_roles requires organizational_unit_ids."
    }
  }
}

# Generated only when the caller does not supply an external_id.
resource "random_uuid" "external_id" {
  count = var.external_id == null ? 1 : 0
}

locals {
  external_id = var.external_id != null ? var.external_id : one(random_uuid.external_id[*].result)
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
  create_legacy_cur            = var.create_legacy_cur
  create_cur2                  = var.create_cur2
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

# Commitment Management is not part of this module yet. It will be a third
# feature (modules/commitment-management) with the same count pattern.
