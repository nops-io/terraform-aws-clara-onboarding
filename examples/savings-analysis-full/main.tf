# Savings Analysis on Full Platform permissions. Run in the payer (management)
# account. Replace the placeholders, then terraform init && terraform apply.

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

module "clara" {
  source = "../.."

  providers = {
    aws           = aws
    aws.us_east_1 = aws.us_east_1
  }

  client_id       = "123456"                     # replace with your Clara client id
  cur_bucket_name = "replace-me-cur-bucket-name" # must be globally unique
  permission_mode = "full"
  create_cur2     = true
}

output "registration" {
  value     = module.clara.registration
  sensitive = true
}
