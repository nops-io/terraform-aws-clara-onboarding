locals {
  # Vendored by scripts/sync_from_clara.py. Do not edit the templates here.
  template_file = var.permission_mode == "full" ? "nops-sa-child-role.yaml" : "nops-sa-child-role-minimal.yaml"
}

resource "aws_cloudformation_stack_set" "child" {
  name             = var.stack_set_name
  description      = "Clara Savings Analysis child read role (${var.permission_mode})"
  permission_model = "SERVICE_MANAGED"
  call_as          = "SELF"
  capabilities     = ["CAPABILITY_NAMED_IAM"]
  template_body    = file("${path.module}/templates/${local.template_file}")

  parameters = {
    PayerRoleArn = var.payer_role_arn
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
