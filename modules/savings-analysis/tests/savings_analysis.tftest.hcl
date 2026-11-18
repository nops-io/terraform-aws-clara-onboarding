mock_provider "aws" {}

mock_provider "aws" {
  alias = "us_east_1"

  mock_data "aws_s3_bucket" {
    defaults = {
      region = "us-east-1"
    }
  }
}

mock_provider "time" {}

variables {
  client_id                    = "42"
  data_connector_principal_arn = "arn:aws:iam::861341088565:role/nops-data-connector"
  external_id                  = "11111111-2222-3333-4444-555555555555"
  cur_bucket_name              = "nops-test-cur-bucket"
}

run "minimal_attaches_minimum_policy_only" {
  command = plan

  variables {
    permission_mode = "minimal"
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  assert {
    condition     = aws_iam_role.integration.name == "nops-integration-role-42"
    error_message = "Role name must be nops-integration-role-<client_id>."
  }

  assert {
    condition     = length(aws_iam_policy.minimum) == 1 && length(aws_iam_policy.full) == 0
    error_message = "Minimal mode must create the Minimum policy and no Full policies."
  }

  assert {
    condition     = length(aws_iam_role_policy_attachment.read_only_access) == 0
    error_message = "Minimal mode must not attach ReadOnlyAccess."
  }

  assert {
    condition     = aws_cur_report_definition.legacy[0].report_name == "nops_cur_42_hourly"
    error_message = "Legacy CUR name must default to nops_cur_<client_id>_hourly."
  }

  assert {
    condition     = length(aws_bcmdataexports_export.cur2) == 0
    error_message = "CUR 2.0 is off by default."
  }
}

run "full_attaches_deny_lists_and_read_only" {
  command = plan

  variables {
    permission_mode = "full"
    create_cur2     = true
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  assert {
    condition     = length(aws_iam_policy.full) == 1 && length(aws_iam_policy.minimum) == 0
    error_message = "Full mode must create the Full policy and no Minimum policy."
  }

  assert {
    condition     = length(aws_iam_policy.full_deny_1) == 1 && length(aws_iam_policy.full_deny_2) == 1 && length(aws_iam_policy.full_s3_data_deny) == 1
    error_message = "Full mode must create both deny lists and the S3 data deny."
  }

  assert {
    condition     = aws_iam_role_policy_attachment.read_only_access[0].policy_arn == "arn:aws:iam::aws:policy/ReadOnlyAccess"
    error_message = "Full mode must attach AWS managed ReadOnlyAccess."
  }

  assert {
    condition     = length(aws_bcmdataexports_export.cur2) == 1
    error_message = "CUR 2.0 must be created when create_cur2 is true."
  }
}

run "trust_is_locked_to_external_id" {
  command = plan

  variables {
    permission_mode = "minimal"
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  assert {
    condition     = jsondecode(aws_iam_role.integration.assume_role_policy).Statement[0].Condition.StringEquals["sts:ExternalId"] == "11111111-2222-3333-4444-555555555555"
    error_message = "Trust policy must require the ExternalId."
  }

  assert {
    condition     = jsondecode(aws_iam_role.integration.assume_role_policy).Statement[0].Principal.AWS == "arn:aws:iam::861341088565:role/nops-data-connector"
    error_message = "Trust principal must be the data connector role."
  }
}

run "s3_data_deny_exempts_only_cur_bucket" {
  command = plan

  variables {
    permission_mode = "full"
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  assert {
    condition     = contains(jsondecode(aws_iam_policy.full_s3_data_deny[0].policy).Statement[0].NotResource, "arn:aws:s3:::nops-test-cur-bucket/*")
    error_message = "S3 data deny must exempt the CUR bucket."
  }

  assert {
    condition     = contains(jsondecode(aws_iam_policy.full_s3_data_deny[0].policy).Statement[0].NotResource, "arn:aws:s3:::*/nops-cur2/*")
    error_message = "S3 data deny must exempt nops-cur2 folders."
  }
}

run "rejects_unknown_permission_mode" {
  command = plan

  variables {
    permission_mode = "everything"
  }

  expect_failures = [var.permission_mode]
}

run "rejects_short_external_id" {
  command = plan

  variables {
    permission_mode = "minimal"
    external_id     = "short"
  }

  expect_failures = [var.external_id]
}

run "existing_bucket_is_never_created_or_written" {
  command = plan

  variables {
    permission_mode   = "minimal"
    create_cur_bucket = false
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  assert {
    condition = (
      length(aws_s3_bucket.cur) == 0 &&
      length(aws_s3_bucket_policy.cur_delivery) == 0 &&
      length(aws_s3_bucket_public_access_block.cur) == 0 &&
      length(aws_s3_bucket_server_side_encryption_configuration.cur) == 0
    )
    error_message = "An existing CUR bucket must not be created or have its configuration or policy changed."
  }

  assert {
    condition     = aws_cur_report_definition.legacy[0].s3_bucket == "nops-test-cur-bucket"
    error_message = "The Legacy CUR must deliver into the existing bucket."
  }

  assert {
    condition     = output.cur_bucket_name == "nops-test-cur-bucket"
    error_message = "The bucket output must name the existing bucket."
  }
}

run "existing_bucket_must_be_in_us_east_1" {
  command = plan

  variables {
    permission_mode   = "minimal"
    create_cur_bucket = false
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  override_data {
    target = data.aws_s3_bucket.existing[0]
    values = {
      region = "eu-west-1"
    }
  }

  expect_failures = [terraform_data.existing_cur_bucket_guard[0]]
}

run "created_bucket_still_gets_the_delivery_policy" {
  command = plan

  variables {
    permission_mode = "minimal"
  }

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  assert {
    condition     = length(aws_s3_bucket.cur) == 1 && length(aws_s3_bucket_policy.cur_delivery) == 1
    error_message = "By default the module creates the bucket and its delivery policy."
  }

  assert {
    condition     = length(data.aws_s3_bucket.existing) == 0
    error_message = "No existing-bucket lookup when the module creates the bucket."
  }
}

