# Savings Analysis plus the child read role across the organization. Run in the
# payer (management) account. The StackSet needs trusted access for CloudFormation
# StackSets on the organization.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}

provider "aws" {
  alias  = "sharesave"
  region = "us-east-1"
  # Used only when enable_commitment_management = true. Point this at the dedicated
  # child account for the ShareSave role, for example with assume_role.
}

module "clara" {
  source = "../.."

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    aws.sharesave = aws.sharesave
  }

  client_id          = "123456"                     # replace with your Clara client id
  cur_bucket_name    = "replace-me-cur-bucket-name" # must be globally unique
  permission_mode    = "full"
  enable_child_roles = true
  # replace with your organization root id
  organizational_unit_ids = ["r-example"]
}

output "registration" {
  value     = module.clara.registration
  sensitive = true
}
