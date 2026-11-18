# Savings Analysis with no wizard step. Terraform creates the AWS resources and registers
# the account with Clara through the API.
#
#   export CLARA_API_KEY=...     # a Clara API key with the aws-onboarding permissions
#   terraform init && terraform apply
#
# Run in the payer (management) account. The key is read from the environment, never
# from this file.

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    clara = {
      source  = "nops-io/clara"
      version = "~> 0.1"
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

# Only used with Commitment Management. The module requires this provider to be passed.
provider "aws" {
  alias  = "sharesave"
  region = "us-east-1"
}

# Reads the API key from CLARA_API_KEY. Use CLARA_API_URL for a non-production API.
provider "clara" {}

data "clara_context" "this" {}

data "aws_caller_identity" "payer" {}

module "clara" {
  source = "../.."

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    aws.sharesave = aws.sharesave
  }

  client_id       = data.clara_context.this.client_id
  cur_bucket_name = "replace-me-cur-bucket-name" # must be globally unique
  permission_mode = "minimal"
}

module "clara_registration" {
  source = "../../modules/registration"

  payer_account_id = data.aws_caller_identity.payer.account_id
  registration     = module.clara.registration
}

output "integration_id" {
  value = module.clara_registration.integration_id
}

output "status" {
  value = module.clara_registration.status
}
