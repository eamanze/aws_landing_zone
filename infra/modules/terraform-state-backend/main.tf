data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_region" "current" {}

locals {
  bucket_name = lower(join("-", [
    var.bucket_name_prefix,
    data.aws_caller_identity.current.account_id,
    data.aws_region.current.region,
  ]))

  account_root_arn = "arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"

  state_principal_arns = distinct([
    for access in values(var.state_access_principals) : access.principal_arn
  ])

  authorized_principal_arns = distinct(concat(
    [local.account_root_arn],
    tolist(var.bucket_administrator_arns),
    local.state_principal_arns,
  ))

  kms_usage_principal_arns = distinct(concat(
    tolist(var.bucket_administrator_arns),
    local.state_principal_arns,
  ))

  required_tags = merge(var.additional_tags, {
    Project     = var.project_name
    Environment = "bootstrap"
    Owner       = var.owner
    ManagedBy   = "terraform"
    CostCenter  = var.cost_center
  })
}

data "aws_iam_policy_document" "kms" {
  statement {
    sid    = "EnableAccountRootRecovery"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = [local.account_root_arn]
    }

    actions   = ["kms:*"]
    resources = ["*"]
  }

  statement {
    sid    = "AllowKeyAdministration"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = tolist(var.kms_administrator_arns)
    }

    actions = [
      "kms:CancelKeyDeletion",
      "kms:CreateAlias",
      "kms:CreateGrant",
      "kms:DescribeKey",
      "kms:DisableKey",
      "kms:EnableKey",
      "kms:EnableKeyRotation",
      "kms:GetKeyPolicy",
      "kms:GetKeyRotationStatus",
      "kms:ListGrants",
      "kms:ListResourceTags",
      "kms:PutKeyPolicy",
      "kms:RevokeGrant",
      "kms:ScheduleKeyDeletion",
      "kms:TagResource",
      "kms:UntagResource",
      "kms:UpdateAlias",
      "kms:UpdateKeyDescription",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "AllowStateEncryptionUse"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = local.kms_usage_principal_arns
    }

    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo",
    ]
    resources = ["*"]
  }
}

resource "aws_kms_key" "terraform_state" {
  description             = "Terraform remote state for ${var.project_name}"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.kms.json
  tags                    = local.required_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_kms_alias" "terraform_state" {
  name          = "alias/${local.bucket_name}"
  target_key_id = aws_kms_key.terraform_state.key_id
}

resource "aws_s3_bucket" "terraform_state" {
  bucket        = local.bucket_name
  force_destroy = false
  tags          = local.required_tags

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    bucket_key_enabled = true

    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.terraform_state.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    id     = "preserve-and-archive-noncurrent-state"
    status = "Enabled"

    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }

    noncurrent_version_transition {
      noncurrent_days = var.noncurrent_version_transition_days
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = var.noncurrent_version_archive_days
      storage_class   = "GLACIER"
    }

    noncurrent_version_expiration {
      noncurrent_days = var.noncurrent_version_expiration_days
    }
  }

  depends_on = [aws_s3_bucket_versioning.terraform_state]
}

data "aws_iam_policy_document" "state_bucket" {
  statement {
    sid    = "DenyInsecureTransport"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*",
    ]

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }

  statement {
    sid    = "DenyUnauthorizedPrincipals"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.terraform_state.arn,
      "${aws_s3_bucket.terraform_state.arn}/*",
    ]

    condition {
      test     = "ArnNotEquals"
      variable = "aws:PrincipalArn"
      values   = local.authorized_principal_arns
    }
  }

  statement {
    sid    = "DenyUnencryptedUploads"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.terraform_state.arn}/*"]

    condition {
      test     = "Null"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["true"]
    }
  }

  statement {
    sid    = "DenyIncorrectEncryption"
    effect = "Deny"

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.terraform_state.arn}/*"]

    condition {
      test     = "StringNotEquals"
      variable = "s3:x-amz-server-side-encryption"
      values   = ["aws:kms"]
    }
  }

  statement {
    sid    = "AllowBucketAdministration"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = tolist(var.bucket_administrator_arns)
    }

    actions = [
      "s3:DeleteBucketPolicy",
      "s3:GetBucket*",
      "s3:ListBucket",
      "s3:ListBucketVersions",
      "s3:PutBucket*",
    ]
    resources = [aws_s3_bucket.terraform_state.arn]
  }

  statement {
    sid    = "AllowBucketAdministratorObjectRecovery"
    effect = "Allow"

    principals {
      type        = "AWS"
      identifiers = tolist(var.bucket_administrator_arns)
    }

    actions = [
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:RestoreObject",
    ]
    resources = ["${aws_s3_bucket.terraform_state.arn}/*"]
  }

  dynamic "statement" {
    for_each = var.state_access_principals

    content {
      sid    = "AllowStateList${substr(sha1(statement.key), 0, 12)}"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = [statement.value.principal_arn]
      }

      actions   = ["s3:ListBucket"]
      resources = [aws_s3_bucket.terraform_state.arn]

      condition {
        test     = "StringLike"
        variable = "s3:prefix"
        values = flatten([
          for prefix in statement.value.state_key_prefixes : [
            prefix,
            "${prefix}/*",
          ]
        ])
      }
    }
  }

  dynamic "statement" {
    for_each = var.state_access_principals

    content {
      sid    = "AllowStateObjects${substr(sha1(statement.key), 0, 12)}"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = [statement.value.principal_arn]
      }

      actions = [
        "s3:GetObject",
        "s3:PutObject",
      ]
      resources = [
        for prefix in statement.value.state_key_prefixes :
        "${aws_s3_bucket.terraform_state.arn}/${prefix}/*"
      ]
    }
  }

  dynamic "statement" {
    for_each = var.state_access_principals

    content {
      sid    = "AllowLockDeletion${substr(sha1(statement.key), 0, 12)}"
      effect = "Allow"

      principals {
        type        = "AWS"
        identifiers = [statement.value.principal_arn]
      }

      actions = ["s3:DeleteObject"]
      resources = [
        for prefix in statement.value.state_key_prefixes :
        "${aws_s3_bucket.terraform_state.arn}/${prefix}/*.tflock"
      ]
    }
  }
}

resource "aws_s3_bucket_policy" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  policy = data.aws_iam_policy_document.state_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.terraform_state]
}

data "aws_iam_policy_document" "state_access" {
  for_each = var.state_access_principals

  statement {
    sid       = "ListStatePrefix"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.terraform_state.arn]

    condition {
      test     = "StringLike"
      variable = "s3:prefix"
      values = flatten([
        for prefix in each.value.state_key_prefixes : [
          prefix,
          "${prefix}/*",
        ]
      ])
    }
  }

  statement {
    sid    = "ReadWriteStateObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
    ]
    resources = [
      for prefix in each.value.state_key_prefixes :
      "${aws_s3_bucket.terraform_state.arn}/${prefix}/*"
    ]
  }

  statement {
    sid     = "DeleteLockFiles"
    effect  = "Allow"
    actions = ["s3:DeleteObject"]
    resources = [
      for prefix in each.value.state_key_prefixes :
      "${aws_s3_bucket.terraform_state.arn}/${prefix}/*.tflock"
    ]
  }

  statement {
    sid    = "UseStateKmsKey"
    effect = "Allow"
    actions = [
      "kms:Decrypt",
      "kms:DescribeKey",
      "kms:Encrypt",
      "kms:GenerateDataKey",
      "kms:ReEncryptFrom",
      "kms:ReEncryptTo",
    ]
    resources = [aws_kms_key.terraform_state.arn]
  }
}
