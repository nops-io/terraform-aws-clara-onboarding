mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111111111111"
    }
  }
}

mock_provider "aws" {
  alias = "sharesave"

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "222222222222"
    }
  }
}

mock_provider "aws" {
  alias = "sharesave_same_as_payer"

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111111111111"
    }
  }
}

variables {
  external_id             = "11111111-2222-3333-4444-555555555555"
  sharesave_external_id   = "66666666-7777-8888-9999-000000000000"
  organizational_unit_ids = ["r-abcd"]
}

run "separate_sharesave_account_plans" {
  command = plan

  providers = {
    aws           = aws
    aws.sharesave = aws.sharesave
  }

  assert {
    condition     = aws_cloudformation_stack.central.name == "nops-cm-central"
    error_message = "Central role stack must be named nops-cm-central."
  }

  assert {
    condition     = aws_cloudformation_stack_set.child.permission_model == "SERVICE_MANAGED"
    error_message = "Child read roles must use a service-managed StackSet."
  }

  assert {
    condition     = strcontains(aws_cloudformation_stack.central.template_body, "NopsCMCrossAccountAssume")
    error_message = "Central stack must use the Clara central role template."
  }

  assert {
    condition     = strcontains(aws_cloudformation_stack.sharesave.template_body, "nops-sharesave-mgt")
    error_message = "ShareSave stack must use the Clara ShareSave template."
  }
}

run "sharesave_in_payer_account_refused" {
  command = plan

  providers = {
    aws           = aws
    aws.sharesave = aws.sharesave_same_as_payer
  }

  expect_failures = [terraform_data.account_guard]
}

run "child_targets_required" {
  command = plan

  variables {
    organizational_unit_ids = []
  }

  providers = {
    aws           = aws
    aws.sharesave = aws.sharesave
  }

  expect_failures = [var.organizational_unit_ids]
}

run "sharesave_defaults_to_the_dual_role_with_console_access" {
  command = plan

  variables {
    sharesave_external_id = "66666666-7777-8888-9999-000000000000"
  }

  providers = {
    aws           = aws
    aws.sharesave = aws.sharesave
  }

  assert {
    condition     = aws_cloudformation_stack.sharesave.parameters["ConsoleAccessAccountId"] == "857624037201"
    error_message = "The dual ShareSave role must trust Clara's console account for Switch Role."
  }

  assert {
    condition     = strcontains(aws_cloudformation_stack.sharesave.template_body, "NopsSharesaveMgtConsole")
    error_message = "Dual mode must deploy the console role template."
  }
}

run "sharesave_single_deploys_the_api_role_only" {
  command = plan

  variables {
    sharesave_external_id = "66666666-7777-8888-9999-000000000000"
    sharesave_template    = "single"
  }

  providers = {
    aws           = aws
    aws.sharesave = aws.sharesave
  }

  assert {
    condition     = !contains(keys(aws_cloudformation_stack.sharesave.parameters), "ConsoleAccessAccountId")
    error_message = "Single mode must not pass the console account parameter."
  }

  assert {
    condition     = !strcontains(aws_cloudformation_stack.sharesave.template_body, "NopsSharesaveMgtConsole")
    error_message = "Single mode must not deploy the console role."
  }
}

run "sharesave_template_must_be_known" {
  command = plan

  variables {
    sharesave_template = "triple"
  }

  providers = {
    aws           = aws
    aws.sharesave = aws.sharesave
  }

  expect_failures = [var.sharesave_template]
}

