mock_provider "aws" {}

variables {
  payer_role_arn          = "arn:aws:iam::111111111111:role/nops-integration-role-42"
  organizational_unit_ids = ["r-abcd"]
}

run "full_uses_full_child_template" {
  command = plan

  variables {
    permission_mode = "full"
  }

  assert {
    condition     = output.child_role_name == "nops-sa-child-role"
    error_message = "Full must deploy nops-sa-child-role."
  }

  assert {
    condition     = aws_cloudformation_stack_set.child.permission_model == "SERVICE_MANAGED"
    error_message = "Child roles must use service-managed StackSets."
  }

  assert {
    condition     = strcontains(aws_cloudformation_stack_set.child.template_body, "nops-sa-child-role")
    error_message = "Template body must be the Full child role template."
  }
}

run "minimal_uses_minimal_child_template" {
  command = plan

  variables {
    permission_mode = "minimal"
  }

  assert {
    condition     = output.child_role_name == "nops-sa-child-role-minimal"
    error_message = "Minimal must deploy nops-sa-child-role-minimal."
  }

  assert {
    condition     = strcontains(aws_cloudformation_stack_set.child.template_body, "nops-sa-child-role-minimal")
    error_message = "Template body must be the minimal child role template."
  }
}

run "rejects_empty_targets" {
  command = plan

  variables {
    permission_mode         = "full"
    organizational_unit_ids = []
  }

  expect_failures = [var.organizational_unit_ids]
}
