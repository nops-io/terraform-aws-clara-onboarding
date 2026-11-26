# Uses a mock of the nops-io/clara provider, so no API key is needed. terraform init still
# downloads the provider from the Terraform Registry.
mock_provider "clara" {}

variables {
  payer_account_id = "123456789012"
}

run "maps_the_root_registration_output_onto_the_resource" {
  command = plan

  variables {
    # Same shape as the root module's registration output, including attributes
    # this module does not use.
    registration = {
      role_arn           = "arn:aws:iam::123456789012:role/nops-integration-role-42"
      external_id        = "11111111-2222-3333-4444-555555555555"
      permission_mode    = "full"
      cur_bucket_name    = "nops-cur-42"
      cur_report_name    = "nops_cur_42_hourly"
      cur_s3_prefix      = "nops-cur"
      cur2_export_name   = "nops_cur2_42_hourly"
      cur2_s3_prefix     = "nops-cur2"
      cur2_export_arn    = "arn:aws:bcm-data-exports:us-east-1:123456789012:export/x"
      child_role_name    = null
      commitment_enabled = false
    }
  }

  assert {
    condition = (
      clara_aws_integration.this.payer_account_id == "123456789012" &&
      clara_aws_integration.this.permission_mode == "full" &&
      clara_aws_integration.this.cur_bucket_name == "nops-cur-42" &&
      clara_aws_integration.this.cur2_export_name == "nops_cur2_42_hourly"
    )
    error_message = "Registration values must reach the clara_aws_integration resource."
  }
}

run "omits_cur2_when_the_root_module_did_not_create_it" {
  command = plan

  variables {
    registration = {
      role_arn         = "arn:aws:iam::123456789012:role/nops-integration-role-42"
      external_id      = "11111111-2222-3333-4444-555555555555"
      permission_mode  = "minimal"
      cur_bucket_name  = "nops-cur-42"
      cur_report_name  = "nops_cur_42_hourly"
      cur_s3_prefix    = "nops-cur"
      cur2_export_name = null
      cur2_s3_prefix   = null
    }
  }

  assert {
    condition     = clara_aws_integration.this.cur2_export_name == null
    error_message = "CUR 2.0 must stay off when the root module did not create it."
  }
}

run "rejects_a_null_registration" {
  command = plan

  variables {
    registration = null
  }

  expect_failures = [var.registration]
}

run "rejects_a_bad_payer_account" {
  command = plan

  variables {
    payer_account_id = "123"
    registration = {
      role_arn        = "arn:aws:iam::123456789012:role/x"
      external_id     = "11111111-2222-3333-4444-555555555555"
      permission_mode = "minimal"
      cur_bucket_name = "nops-cur-42"
    }
  }

  expect_failures = [var.payer_account_id]
}
