data "aws_caller_identity" "current" {}

# Trust: Clara's data connector role, locked to this ExternalId.
resource "aws_iam_role" "integration" {
  name = local.integration_role_name
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = { AWS = var.data_connector_principal_arn }
        Action    = "sts:AssumeRole"
        Condition = {
          StringEquals = {
            "sts:ExternalId" = var.external_id
          }
        }
      }
    ]
  })
  tags = var.tags
}

# nOpsBucketPolicy: read-only access to the CUR bucket. Same statements as the
# CloudFormation template (NopsBucketPolicy), for both permission modes.
resource "aws_iam_policy" "bucket" {
  name        = "nOpsBucketPolicy"
  description = "nOps — CUR S3 bucket access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketPolicy",
          "s3:GetEncryptionConfiguration",
          "s3:GetBucketVersioning",
          "s3:GetBucketPolicyStatus",
          "s3:GetBucketLocation",
          "s3:GetBucketAcl",
          "s3:GetBucketLogging",
          "s3:GetObject",
        ]
        Resource = [local.bucket_arn, "${local.bucket_arn}/*"]
      }
    ]
  })
  tags = var.tags
}

# Minimum Platform (Savings Analysis).
resource "aws_iam_policy" "minimum" {
  count       = local.is_full ? 0 : 1
  name        = "nOpsMinimumPlatformPermissions"
  description = "nOps Savings Analysis - Minimum Platform permissions"
  policy      = file("${path.module}/policies/minimum-platform.json")
  tags        = var.tags
}

# Full Platform (Inform & Operate), with its Deny lists and S3 data deny.
resource "aws_iam_policy" "full" {
  count       = local.is_full ? 1 : 0
  name        = "nOpsFullPlatformPermissions"
  description = "nOps Full Platform - allow list on top of ReadOnlyAccess"
  policy      = file("${path.module}/policies/full-platform.json")
  tags        = var.tags
}

resource "aws_iam_policy" "full_deny_1" {
  count       = local.is_full ? 1 : 0
  name        = "nOpsFullPlatformDenyList1"
  description = "nOps Full Platform - Deny list part 1 of 2"
  policy      = file("${path.module}/policies/full-deny-1.json")
  tags        = var.tags
}

resource "aws_iam_policy" "full_deny_2" {
  count       = local.is_full ? 1 : 0
  name        = "nOpsFullPlatformDenyList2"
  description = "nOps Full Platform - Deny list part 2 of 2"
  policy      = file("${path.module}/policies/full-deny-2.json")
  tags        = var.tags
}

resource "aws_iam_policy" "full_s3_data_deny" {
  count       = local.is_full ? 1 : 0
  name        = "nOpsFullPlatformS3DataDeny"
  description = "nOps Full Platform - Deny S3 object data reads outside the nOps CUR bucket(s)"
  policy      = local.s3_data_deny_policy
  tags        = var.tags
}

resource "aws_iam_role_policy_attachment" "bucket" {
  role       = aws_iam_role.integration.name
  policy_arn = aws_iam_policy.bucket.arn
}

resource "aws_iam_role_policy_attachment" "minimum" {
  count      = local.is_full ? 0 : 1
  role       = aws_iam_role.integration.name
  policy_arn = aws_iam_policy.minimum[0].arn
}

resource "aws_iam_role_policy_attachment" "full" {
  count      = local.is_full ? 1 : 0
  role       = aws_iam_role.integration.name
  policy_arn = aws_iam_policy.full[0].arn
}

resource "aws_iam_role_policy_attachment" "full_deny_1" {
  count      = local.is_full ? 1 : 0
  role       = aws_iam_role.integration.name
  policy_arn = aws_iam_policy.full_deny_1[0].arn
}

resource "aws_iam_role_policy_attachment" "full_deny_2" {
  count      = local.is_full ? 1 : 0
  role       = aws_iam_role.integration.name
  policy_arn = aws_iam_policy.full_deny_2[0].arn
}

resource "aws_iam_role_policy_attachment" "full_s3_data_deny" {
  count      = local.is_full ? 1 : 0
  role       = aws_iam_role.integration.name
  policy_arn = aws_iam_policy.full_s3_data_deny[0].arn
}

# Full Platform builds on the AWS managed ReadOnlyAccess policy.
resource "aws_iam_role_policy_attachment" "read_only_access" {
  count      = local.is_full ? 1 : 0
  role       = aws_iam_role.integration.name
  policy_arn = "arn:aws:iam::aws:policy/ReadOnlyAccess"
}

resource "time_sleep" "iam_propagation" {
  create_duration = var.iam_propagation_wait

  depends_on = [
    aws_iam_role_policy_attachment.bucket,
    aws_iam_role_policy_attachment.minimum,
    aws_iam_role_policy_attachment.full,
    aws_iam_role_policy_attachment.full_deny_1,
    aws_iam_role_policy_attachment.full_deny_2,
    aws_iam_role_policy_attachment.full_s3_data_deny,
    aws_iam_role_policy_attachment.read_only_access,
  ]
}
