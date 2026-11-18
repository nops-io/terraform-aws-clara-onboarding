mock_provider "aws" {
  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "111111111111"
    }
  }
}

mock_provider "aws" {
  alias = "us_east_1"
}

mock_provider "aws" {
  alias = "sharesave"

  mock_data "aws_caller_identity" {
    defaults = {
      account_id = "222222222222"
    }
  }
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
    aws.sharesave = aws.sharesave
  }

  assert {
    condition     = length(module.savings_analysis) == 1 && length(module.child_roles) == 0 && length(module.commitment_management) == 0
    error_message = "Savings Analysis alone must create only the payer module."
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
    aws.sharesave = aws.sharesave
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

run "commitment_management_with_savings_analysis" {
  command = plan

  variables {
    enable_commitment_management = true
    organizational_unit_ids      = ["r-abcd"]
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    aws.sharesave = aws.sharesave
  }

  assert {
    condition     = length(module.commitment_management) == 1
    error_message = "Commitment Management must be created when enabled."
  }

}

run "commitment_management_without_savings_analysis_refused" {
  command = plan

  variables {
    enable_savings_analysis      = false
    enable_commitment_management = true
    organizational_unit_ids      = ["r-abcd"]
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    aws.sharesave = aws.sharesave
  }

  expect_failures = [terraform_data.feature_guard]
}

run "commitment_management_without_targets_refused" {
  command = plan

  variables {
    enable_commitment_management = true
    organizational_unit_ids      = []
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    aws.sharesave = aws.sharesave
  }

  expect_failures = [terraform_data.feature_guard]
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
    aws.sharesave = aws.sharesave
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
    aws.sharesave = aws.sharesave
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
    aws.sharesave = aws.sharesave
  }

  expect_failures = [terraform_data.feature_guard]
}

run "external_ids_generated_when_not_supplied" {
  command = plan

  variables {
    enable_commitment_management = true
    organizational_unit_ids      = ["r-abcd"]
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    aws.sharesave = aws.sharesave
  }

  assert {
    condition     = length(random_uuid.external_id) == 1 && length(random_uuid.commitment_external_id) == 1 && length(random_uuid.sharesave_external_id) == 1
    error_message = "Three ExternalIds must be generated when none are supplied."
  }
}

run "external_ids_supplied_are_used" {
  command = plan

  variables {
    external_id                  = "11111111-2222-3333-4444-555555555555"
    commitment_external_id       = "22222222-2222-3333-4444-555555555555"
    sharesave_external_id        = "33333333-2222-3333-4444-555555555555"
    enable_commitment_management = true
    organizational_unit_ids      = ["r-abcd"]
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    aws.sharesave = aws.sharesave
  }

  assert {
    condition     = length(random_uuid.external_id) == 0 && length(random_uuid.commitment_external_id) == 0 && length(random_uuid.sharesave_external_id) == 0
    error_message = "No ExternalIds are generated when the caller supplies them."
  }
}

run "wizard_cur_settings_are_passed_through" {
  command = plan

  variables {
    create_cur2      = true
    cur_report_name  = "wizard_report"
    cur_s3_prefix    = "wizard-prefix"
    cur2_export_name = "wizard_cur2"
    cur2_s3_prefix   = "wizard-cur2"
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    aws.sharesave = aws.sharesave
  }

  assert {
    condition = (
      output.registration.cur_report_name == "wizard_report" &&
      output.registration.cur_s3_prefix == "wizard-prefix" &&
      output.registration.cur2_export_name == "wizard_cur2" &&
      output.registration.cur2_s3_prefix == "wizard-cur2"
    )
    error_message = "Every CUR setting the wizard can edit must reach the module and the registration output."
  }
}

run "defaults_match_the_wizard_suggestions" {
  command = plan

  variables {
    create_cur2 = true
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    aws.sharesave = aws.sharesave
  }

  assert {
    condition = (
      output.registration.cur_report_name == "nops_cur_42_hourly" &&
      output.registration.cur_s3_prefix == "nops-cur" &&
      output.registration.cur2_export_name == "nops_cur2_42_hourly" &&
      output.registration.cur2_s3_prefix == "nops-cur2"
    )
    error_message = "Defaults must equal the wizard's suggested names and prefixes."
  }
}

run "rejects_prefix_with_invalid_characters" {
  command = plan

  variables {
    cur_s3_prefix = "bad prefix!"
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    aws.sharesave = aws.sharesave
  }

  expect_failures = [var.cur_s3_prefix]
}
