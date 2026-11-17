mock_provider "aws" {}

mock_provider "aws" {
  alias = "us_east_1"
}

mock_provider "random" {}

mock_provider "time" {}

variables {
  client_id       = "42"
  cur_bucket_name = "nops-test-cur-bucket"
}

run "savings_analysis_only" {
  command = plan

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  assert {
    condition     = length(module.savings_analysis) == 1 && length(module.child_roles) == 0
    error_message = "Savings Analysis alone must create the payer module and no child roles."
  }

  assert {
    condition     = output.role_name == "nops-integration-role-42"
    error_message = "Role name must follow the client id."
  }
}

run "savings_analysis_with_child_roles" {
  command = plan

  variables {
    enable_child_roles      = true
    permission_mode         = "full"
    organizational_unit_ids = ["r-abcd"]
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  assert {
    condition     = length(module.child_roles) == 1
    error_message = "Child roles must be created when enabled."
  }

  assert {
    condition     = output.child_role_name == "nops-sa-child-role"
    error_message = "Full mode must use the Full child role."
  }
}

run "child_roles_without_savings_analysis_refused" {
  command = plan

  variables {
    enable_savings_analysis = false
    enable_child_roles      = true
    organizational_unit_ids = ["r-abcd"]
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  expect_failures = [terraform_data.feature_guard]
}

run "nothing_enabled_refused" {
  command = plan

  variables {
    enable_savings_analysis = false
    enable_child_roles      = false
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  expect_failures = [terraform_data.feature_guard]
}

run "child_roles_without_targets_refused" {
  command = plan

  variables {
    enable_child_roles      = true
    organizational_unit_ids = []
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  expect_failures = [terraform_data.feature_guard]
}

run "external_id_generated_when_not_supplied" {
  command = plan

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  assert {
    condition     = length(random_uuid.external_id) == 1
    error_message = "A random ExternalId must be generated when none is supplied."
  }
}

run "external_id_supplied_is_used" {
  command = plan

  variables {
    external_id = "11111111-2222-3333-4444-555555555555"
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  assert {
    condition     = length(random_uuid.external_id) == 0
    error_message = "No random ExternalId when the caller supplies one."
  }
}
