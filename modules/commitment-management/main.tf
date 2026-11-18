locals {
  sharesave_template_file = var.sharesave_template == "dual" ? "nops-cm-sharesave-dual.yaml" : "nops-cm-sharesave-role.yaml"
}

data "aws_caller_identity" "payer" {}

data "aws_caller_identity" "sharesave" {
  provider = aws.sharesave
}

# Clara's ShareSave role is designed for a dedicated child account. Refuse the payer.
resource "terraform_data" "account_guard" {
  lifecycle {
    precondition {
      condition     = data.aws_caller_identity.sharesave.account_id != data.aws_caller_identity.payer.account_id
      error_message = "The ShareSave role must be in a dedicated child account. The aws.sharesave provider points at the payer account."
    }
  }
}

# Central role: the Clara bridge assumes this role (with ExternalId) and it can assume
# the child read roles. Deployed in the payer. The template is Clara's own.
resource "aws_cloudformation_stack" "central" {
  name          = "nops-cm-central"
  template_body = file("${path.module}/templates/nops-cm-central-role.yaml")
  capabilities  = ["CAPABILITY_NAMED_IAM"]

  parameters = {
    NopsCMAssumerRoleArn = var.cm_bridge_principal_arn
    ExternalId           = var.external_id
  }

  tags = var.tags
}

# Payer read role. StackSets skip the management account, so the payer gets its own
# NopsCMReadEC2Instances stack. Same template as the member roles.
resource "aws_cloudformation_stack" "payer_read" {
  name          = "nops-cm-payer-read"
  template_body = file("${path.module}/templates/nops-cm-child-role.yaml")
  capabilities  = ["CAPABILITY_NAMED_IAM"]

  parameters = {
    CentralRoleArn = aws_cloudformation_stack.central.outputs["RoleArn"]
  }

  tags = var.tags
}

# Child read roles (NopsCMReadEC2Instances) in every member account, through a
# service-managed StackSet.
resource "aws_cloudformation_stack_set" "child" {
  name             = "nops-cm-child-roles"
  description      = "Clara Commitment Management child read role"
  permission_model = "SERVICE_MANAGED"
  call_as          = "SELF"
  capabilities     = ["CAPABILITY_NAMED_IAM"]
  template_body    = file("${path.module}/templates/nops-cm-child-role.yaml")

  parameters = {
    CentralRoleArn = aws_cloudformation_stack.central.outputs["RoleArn"]
  }

  auto_deployment {
    enabled                          = true
    retain_stacks_on_account_removal = true
  }

  tags = var.tags
}

resource "aws_cloudformation_stack_set_instance" "child" {
  stack_set_name            = aws_cloudformation_stack_set.child.name
  stack_set_instance_region = var.stack_set_region

  deployment_targets {
    organizational_unit_ids = var.organizational_unit_ids
  }
}

# ShareSave role (nops-sharesave-mgt): purchasing and Cost Explorer. Deployed in a
# dedicated child account through the aws.sharesave provider. "dual" also creates the
# console role that Clara's Switch Role uses, as the Commitment Management wizard does.
resource "aws_cloudformation_stack" "sharesave" {
  provider      = aws.sharesave
  name          = "nops-cm-sharesave"
  template_body = file("${path.module}/templates/${local.sharesave_template_file}")
  capabilities  = ["CAPABILITY_NAMED_IAM"]

  parameters = merge(
    {
      NopsCrossAccountRoleArn = var.sharesave_bridge_principal_arn
      ExternalId              = var.sharesave_external_id
    },
    var.sharesave_template == "dual" ? { ConsoleAccessAccountId = var.console_access_account_id } : {}
  )

  tags       = var.tags
  depends_on = [terraform_data.account_guard]
}
