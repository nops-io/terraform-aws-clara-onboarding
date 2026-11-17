terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source = "hashicorp/aws"
      # BCM data exports and the CUR report definition are only available in us-east-1,
      # so the caller passes a us-east-1 provider as aws.us_east_1.
      version               = "~> 6.0"
      configuration_aliases = [aws.us_east_1]
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}
