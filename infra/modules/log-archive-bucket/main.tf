locals {
  should_create_bucket = var.create_bucket && !var.control_tower_owned_bucket

  effective_kms_key_arn = var.create_kms_key ? try(aws_kms_key.log_archive[0].arn, null) : var.kms_key_arn
  safe_account_id       = coalesce(var.current_account_id, "000000000000")
  bucket_arn            = "arn:${var.aws_partition}:s3:::${coalesce(var.bucket_name, "placeholder-log-bucket")}"

  cloudtrail_object_arns = [
    for source_arn in sort(tolist(var.cloudtrail_source_arns)) :
    "arn:${var.aws_partition}:s3:::${var.bucket_name}/${trim(var.cloudtrail_log_prefix, "/")}/AWSLogs/${split(":", source_arn)[4]}/*"
  ]

  flow_log_write_resources = flatten([
    for source in values(var.flow_log_sources) : [
      "arn:${var.aws_partition}:s3:::${var.bucket_name}/${trim(source.prefix, "/")}/AWSLogs/${source.account_id}/*",
      "arn:${var.aws_partition}:s3:::${var.bucket_name}/${trim(source.prefix, "/")}/AWSLogs/aws-account-id=${source.account_id}/*",
    ]
  ])

  flow_log_source_arns = flatten([
    for source in values(var.flow_log_sources) : [
      for region in source.regions : "arn:${var.aws_partition}:logs:${region}:${source.account_id}:*"
    ]
  ])

  kms_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "EnableRootAccountKeyAdministration"
          Effect    = "Allow"
          Principal = { AWS = "arn:${var.aws_partition}:iam::${local.safe_account_id}:root" }
          Action    = "kms:*"
          Resource  = "*"
        }
      ],
      [
        for role_arn in sort(tolist(var.kms_administrator_role_arns)) : {
          Sid       = "AllowApprovedKeyAdministrator${index(sort(tolist(var.kms_administrator_role_arns)), role_arn)}"
          Effect    = "Allow"
          Principal = { AWS = role_arn }
          Action = [
            "kms:CancelKeyDeletion",
            "kms:CreateAlias",
            "kms:DeleteAlias",
            "kms:Describe*",
            "kms:DisableKey",
            "kms:EnableKey",
            "kms:Get*",
            "kms:List*",
            "kms:PutKeyPolicy",
            "kms:ScheduleKeyDeletion",
            "kms:TagResource",
            "kms:UntagResource",
            "kms:UpdateAlias",
            "kms:UpdateKeyDescription",
          ]
          Resource = "*"
        }
      ],
      [
        for source_arn in sort(tolist(var.cloudtrail_source_arns)) : {
          Sid       = "AllowCloudTrailEncryptLogs${index(sort(tolist(var.cloudtrail_source_arns)), source_arn)}"
          Effect    = "Allow"
          Principal = { Service = "cloudtrail.amazonaws.com" }
          Action    = "kms:GenerateDataKey*"
          Resource  = "*"
          Condition = {
            StringEquals = {
              "aws:SourceArn" = source_arn
            }
            StringLike = {
              "kms:EncryptionContext:aws:cloudtrail:arn" = "arn:${var.aws_partition}:cloudtrail:*:${split(":", source_arn)[4]}:trail/*"
            }
          }
        }
      ],
      [
        for source_key, source in var.flow_log_sources : {
          Sid       = "AllowVpcFlowLogsEncrypt${source_key}"
          Effect    = "Allow"
          Principal = { Service = "delivery.logs.amazonaws.com" }
          Action = [
            "kms:GenerateDataKey*",
            "kms:Encrypt",
          ]
          Resource = "*"
        }
      ],
      [
        for role_arn in sort(tolist(var.log_reader_role_arns)) : {
          Sid       = "AllowApprovedLogReaderDecrypt${index(sort(tolist(var.log_reader_role_arns)), role_arn)}"
          Effect    = "Allow"
          Principal = { AWS = role_arn }
          Action = [
            "kms:Decrypt",
            "kms:DescribeKey",
          ]
          Resource = "*"
        }
      ]
    )
  })
}

resource "aws_kms_key" "log_archive" {
  count = local.should_create_bucket && var.create_kms_key ? 1 : 0

  description             = "Terraform-owned log archive encryption key"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  policy                  = local.kms_policy_json
  tags                    = var.tags

  lifecycle {
    precondition {
      condition     = var.current_account_id != null
      error_message = "current_account_id is required when create_kms_key=true."
    }
  }
}

resource "aws_kms_alias" "log_archive" {
  count = local.should_create_bucket && var.create_kms_key && var.kms_key_alias != null ? 1 : 0

  name          = "alias/${var.kms_key_alias}"
  target_key_id = aws_kms_key.log_archive[0].key_id
}

resource "aws_s3_bucket" "log_archive" {
  count = local.should_create_bucket ? 1 : 0

  bucket              = var.bucket_name
  force_destroy       = var.force_destroy
  object_lock_enabled = var.object_lock_enabled
  tags                = var.tags

  lifecycle {
    precondition {
      condition     = var.bucket_name != null
      error_message = "bucket_name is required when create_bucket=true."
    }

    precondition {
      condition     = !var.control_tower_owned_bucket
      error_message = "This module must not manage a Control Tower-owned Log Archive bucket."
    }

    precondition {
      condition     = var.create_kms_key || var.kms_key_arn != null
      error_message = "A Terraform-owned log bucket requires either create_kms_key=true or kms_key_arn."
    }
  }
}

resource "aws_s3_bucket_public_access_block" "log_archive" {
  count = local.should_create_bucket ? 1 : 0

  bucket                  = aws_s3_bucket.log_archive[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "log_archive" {
  count = local.should_create_bucket ? 1 : 0

  bucket = aws_s3_bucket.log_archive[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "log_archive" {
  count = local.should_create_bucket ? 1 : 0

  bucket = aws_s3_bucket.log_archive[0].id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = local.effective_kms_key_arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_ownership_controls" "log_archive" {
  count = local.should_create_bucket ? 1 : 0

  bucket = aws_s3_bucket.log_archive[0].id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "log_archive" {
  count = local.should_create_bucket ? 1 : 0

  bucket = aws_s3_bucket.log_archive[0].id

  rule {
    id     = "log-retention"
    status = "Enabled"

    filter {}

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }

    dynamic "transition" {
      for_each = var.transition_to_ia_days == null ? [] : [var.transition_to_ia_days]
      content {
        days          = transition.value
        storage_class = "STANDARD_IA"
      }
    }

    dynamic "transition" {
      for_each = var.transition_to_glacier_days == null ? [] : [var.transition_to_glacier_days]
      content {
        days          = transition.value
        storage_class = "GLACIER"
      }
    }

    dynamic "expiration" {
      for_each = var.expiration_days == null ? [] : [var.expiration_days]
      content {
        days = expiration.value
      }
    }
  }
}

locals {
  bucket_policy_json = jsonencode({
    Version = "2012-10-17"
    Statement = concat(
      [
        {
          Sid       = "DenyInsecureTransport"
          Effect    = "Deny"
          Principal = "*"
          Action    = "s3:*"
          Resource = [
            local.bucket_arn,
            "${local.bucket_arn}/*",
          ]
          Condition = {
            Bool = {
              "aws:SecureTransport" = "false"
            }
          }
        }
      ],
      [
        for source_arn in sort(tolist(var.cloudtrail_source_arns)) : {
          Sid       = "AWSCloudTrailAclCheck${index(sort(tolist(var.cloudtrail_source_arns)), source_arn)}"
          Effect    = "Allow"
          Principal = { Service = "cloudtrail.amazonaws.com" }
          Action    = "s3:GetBucketAcl"
          Resource  = local.bucket_arn
          Condition = {
            ArnEquals = {
              "aws:SourceArn" = source_arn
            }
          }
        }
      ],
      [
        for source_arn in sort(tolist(var.cloudtrail_source_arns)) : {
          Sid       = "AWSCloudTrailWrite${index(sort(tolist(var.cloudtrail_source_arns)), source_arn)}"
          Effect    = "Allow"
          Principal = { Service = "cloudtrail.amazonaws.com" }
          Action    = "s3:PutObject"
          Resource  = "arn:${var.aws_partition}:s3:::${var.bucket_name}/${trim(var.cloudtrail_log_prefix, "/")}/AWSLogs/${split(":", source_arn)[4]}/*"
          Condition = {
            StringEquals = {
              "s3:x-amz-acl" = "bucket-owner-full-control"
            }
            ArnEquals = {
              "aws:SourceArn" = source_arn
            }
          }
        }
      ],
      [
        for source_key, source in var.flow_log_sources : {
          Sid       = "AWSLogDeliveryWrite${source_key}"
          Effect    = "Allow"
          Principal = { Service = "delivery.logs.amazonaws.com" }
          Action    = "s3:PutObject"
          Resource = [
            "arn:${var.aws_partition}:s3:::${var.bucket_name}/${trim(source.prefix, "/")}/AWSLogs/${source.account_id}/*",
            "arn:${var.aws_partition}:s3:::${var.bucket_name}/${trim(source.prefix, "/")}/AWSLogs/aws-account-id=${source.account_id}/*",
          ]
          Condition = {
            StringEquals = {
              "s3:x-amz-acl"      = "bucket-owner-full-control"
              "aws:SourceAccount" = source.account_id
            }
            ArnLike = {
              "aws:SourceArn" = [
                for region in source.regions : "arn:${var.aws_partition}:logs:${region}:${source.account_id}:*"
              ]
            }
          }
        }
      ],
      [
        for source_key, source in var.flow_log_sources : {
          Sid       = "AWSLogDeliveryAclCheck${source_key}"
          Effect    = "Allow"
          Principal = { Service = "delivery.logs.amazonaws.com" }
          Action    = "s3:GetBucketAcl"
          Resource  = local.bucket_arn
          Condition = {
            StringEquals = {
              "aws:SourceAccount" = source.account_id
            }
            ArnLike = {
              "aws:SourceArn" = [
                for region in source.regions : "arn:${var.aws_partition}:logs:${region}:${source.account_id}:*"
              ]
            }
          }
        }
      ],
      [
        for role_arn in sort(tolist(var.log_reader_role_arns)) : {
          Sid       = "AllowApprovedLogReader${index(sort(tolist(var.log_reader_role_arns)), role_arn)}"
          Effect    = "Allow"
          Principal = { AWS = role_arn }
          Action = [
            "s3:GetBucketLocation",
            "s3:GetObject",
            "s3:GetObjectVersion",
            "s3:ListBucket",
          ]
          Resource = [
            local.bucket_arn,
            "${local.bucket_arn}/*",
          ]
        }
      ]
    )
  })
}

resource "aws_s3_bucket_policy" "log_archive" {
  count = local.should_create_bucket ? 1 : 0

  bucket = aws_s3_bucket.log_archive[0].id
  policy = local.bucket_policy_json
}
