terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
      # aws.us_east_1: CUR, BCM data exports and the CUR delivery bucket are us-east-1 only.
      # aws.sharesave: the ShareSave role lives in a dedicated child account, not the payer.
      configuration_aliases = [aws.us_east_1, aws.sharesave]
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}
