# Savings Analysis plus Commitment Management. The central, payer read and child roles
# are deployed from the payer (management) account. The ShareSave role is deployed
# into a dedicated child account through the aws.sharesave provider.

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

# The ShareSave role must be in a dedicated child account, not the payer.
provider "aws" {
  alias  = "sharesave"
  region = "us-east-1"
  assume_role {
    role_arn = "arn:aws:iam::210987654321:role/OrganizationAccountAccessRole" # replace with the role in your child account
  }
}

module "clara" {
  source = "../.."

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
    aws.sharesave = aws.sharesave
  }

  client_id                    = "123456"                     # replace with your Clara client id
  cur_bucket_name              = "replace-me-cur-bucket-name" # must be globally unique
  permission_mode              = "full"
  enable_commitment_management = true
  # replace with your organization root id
  organizational_unit_ids = ["r-example"]
}

output "registration" {
  value     = module.clara.registration
  sensitive = true
}
