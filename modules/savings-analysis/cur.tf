# CUR delivery bucket. CUR and CUR 2.0 only exist in us-east-1, so the bucket lives
# there too.
#
# create_cur_bucket = true (default): the module creates the bucket and the delivery
# policy the billing services need.
#
# create_cur_bucket = false: deliver into a bucket the customer already owns. The module
# then never creates, configures or writes a policy on that bucket, because a bucket
# policy is a single document and would replace the one the customer has. The customer's
# bucket must already grant billingreports.amazonaws.com (Legacy CUR) and
# bcm-data-exports.amazonaws.com (CUR 2.0) the same statements the module writes below.
# The CloudFormation path behaves the same way.

resource "aws_s3_bucket" "cur" {
  provider = aws.us_east_1
  count    = var.create_cur_bucket ? 1 : 0
  bucket   = var.cur_bucket_name
  tags     = var.tags
}

resource "aws_s3_bucket_public_access_block" "cur" {
  provider                = aws.us_east_1
  count                   = var.create_cur_bucket ? 1 : 0
  bucket                  = aws_s3_bucket.cur[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "cur" {
  provider = aws.us_east_1
  count    = var.create_cur_bucket ? 1 : 0
  bucket   = aws_s3_bucket.cur[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Read only when the bucket already exists. Fails the plan when it is missing.
data "aws_s3_bucket" "existing" {
  provider = aws.us_east_1
  count    = var.create_cur_bucket ? 0 : 1
  bucket   = var.cur_bucket_name
}

# Clara's report and export writes go to the bucket in us-east-1, so an existing bucket
# must be there too.
resource "terraform_data" "existing_cur_bucket_guard" {
  count = var.create_cur_bucket ? 0 : 1

  lifecycle {
    precondition {
      condition     = data.aws_s3_bucket.existing[0].region == "us-east-1"
      error_message = "The existing CUR bucket must be in us-east-1. Its region is ${data.aws_s3_bucket.existing[0].region}."
    }
  }
}

# The CloudFormation template writes this policy for the bucket it creates. Without
# it, PutReportDefinition and the CUR 2.0 export fail with "Failed to verify customer
# bucket permission". Same statements, scoped to this bucket.
resource "aws_s3_bucket_policy" "cur_delivery" {
  provider = aws.us_east_1
  count    = var.create_cur_bucket ? 1 : 0
  bucket   = aws_s3_bucket.cur[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "NopsCurGetBucketMetadata"
        Effect    = "Allow"
        Principal = { Service = "billingreports.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:GetBucketPolicy"]
        Resource  = local.bucket_arn
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
            "aws:SourceArn"     = "arn:aws:cur:us-east-1:${local.account_id}:definition/*"
          }
        }
      },
      {
        Sid       = "NopsCurPutObject"
        Effect    = "Allow"
        Principal = { Service = "billingreports.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${local.bucket_arn}/*"
        Condition = {
          StringEquals = {
            "aws:SourceAccount" = local.account_id
            "aws:SourceArn"     = "arn:aws:cur:us-east-1:${local.account_id}:definition/*"
          }
        }
      },
      {
        Sid       = "NopsCur2GetBucketMetadata"
        Effect    = "Allow"
        Principal = { Service = "bcm-data-exports.amazonaws.com" }
        Action    = ["s3:GetBucketAcl", "s3:GetBucketPolicy"]
        Resource  = local.bucket_arn
        Condition = {
          StringEquals = { "aws:SourceAccount" = local.account_id }
          ArnLike      = { "aws:SourceArn" = "arn:aws:bcm-data-exports:us-east-1:${local.account_id}:export/*" }
        }
      },
      {
        Sid       = "NopsCur2PutObject"
        Effect    = "Allow"
        Principal = { Service = "bcm-data-exports.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource  = "${local.bucket_arn}/*"
        Condition = {
          StringEquals = { "aws:SourceAccount" = local.account_id }
          ArnLike      = { "aws:SourceArn" = "arn:aws:bcm-data-exports:us-east-1:${local.account_id}:export/*" }
        }
      },
    ]
  })

  depends_on = [aws_s3_bucket_public_access_block.cur]
}

# Legacy CUR, the report Clara's Savings Analysis ingests.
resource "aws_cur_report_definition" "legacy" {
  provider = aws.us_east_1
  count    = var.create_legacy_cur ? 1 : 0

  report_name                = local.cur_report_name
  time_unit                  = "HOURLY"
  format                     = "Parquet"
  compression                = "Parquet"
  additional_schema_elements = ["RESOURCES", "SPLIT_COST_ALLOCATION_DATA"]
  s3_bucket                  = var.cur_bucket_name
  s3_prefix                  = var.cur_s3_prefix
  s3_region                  = "us-east-1"
  report_versioning          = "OVERWRITE_REPORT"
  refresh_closed_reports     = true

  depends_on = [aws_s3_bucket_policy.cur_delivery]
}

# CUR 2.0 (BCM data export). Same columns and output as the CloudFormation template.
resource "aws_bcmdataexports_export" "cur2" {
  provider = aws.us_east_1
  count    = var.create_cur2 ? 1 : 0

  export {
    name = local.cur2_export_name

    data_query {
      query_statement = local.cur2_query

      table_configurations = {
        COST_AND_USAGE_REPORT = {
          TIME_GRANULARITY                      = "HOURLY"
          INCLUDE_RESOURCES                     = "TRUE"
          INCLUDE_SPLIT_COST_ALLOCATION_DATA    = "TRUE"
          INCLUDE_IAM_PRINCIPAL_DATA            = "TRUE"
          INCLUDE_CAPACITY_RESERVATION_DATA     = "TRUE"
          INCLUDE_MANUAL_DISCOUNT_COMPATIBILITY = "FALSE"
          BILLING_VIEW_ARN                      = "arn:aws:billing::${local.account_id}:billingview/primary"
        }
      }
    }

    destination_configurations {
      s3_destination {
        s3_bucket = var.cur_bucket_name
        s3_prefix = var.cur2_s3_prefix
        s3_region = "us-east-1"

        s3_output_configurations {
          overwrite   = "OVERWRITE_REPORT"
          format      = "PARQUET"
          compression = "PARQUET"
          output_type = "CUSTOM"
        }
      }
    }

    refresh_cadence {
      frequency = "SYNCHRONOUS"
    }
  }

  depends_on = [aws_s3_bucket_policy.cur_delivery]
}
