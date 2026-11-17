terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
      # The ShareSave role must be in a dedicated child account, so the caller passes
      # a second provider configured for that account.
      configuration_aliases = [aws.sharesave]
    }
  }
}
