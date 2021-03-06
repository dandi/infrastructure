resource "aws_s3_bucket" "sponsored_bucket" {
  provider = aws.sponsored

  bucket = "dandiarchive"
  // Public access is granted via a bucket policy, not a canned ACL
  acl = "private"

  cors_rule {
    allowed_origins = [
      "*",
    ]
    allowed_methods = [
      "PUT",
      "POST",
      "GET",
      "DELETE",
    ]
    allowed_headers = [
      "*"
    ]
    expose_headers = [
      "ETag",
    ]
    max_age_seconds = 3000
  }

  logging {
    target_bucket = aws_s3_bucket.sponsored_bucket_logs.id
  }

  versioning {
    enabled = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_ownership_controls" "sponsored_bucket" {
  bucket = aws_s3_bucket.sponsored_bucket.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket" "sponsored_bucket_logs" {
  provider = aws.sponsored

  bucket = "dandiarchive-logs"

  grant {
    type = "Group"
    uri  = "http://acs.amazonaws.com/groups/s3/LogDelivery"
    permissions = [
      "READ_ACP",
      "WRITE",
    ]
  }
  grant {
    type = "CanonicalUser"
    id   = data.aws_canonical_user_id.sponsored_account.id
    permissions = [
      "FULL_CONTROL",
    ]
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_s3_bucket_policy" "sponsored_bucket" {
  provider = aws.sponsored

  bucket = aws_s3_bucket.sponsored_bucket.id
  policy = data.aws_iam_policy_document.sponsored_bucket.json
}

data "aws_iam_policy_document" "sponsored_bucket" {
  version = "2008-10-17"

  statement {
    principals {
      identifiers = ["*"]
      type        = "*"
    }
    actions = [
      "s3:List*",
      "s3:Get*",
    ]
    resources = [
      "${aws_s3_bucket.sponsored_bucket.arn}/*",
      aws_s3_bucket.sponsored_bucket.arn,
    ]
  }

  statement {
    sid = "S3PolicyStmt-DO-NOT-MODIFY-1569973164923"
    principals {
      identifiers = ["s3.amazonaws.com"]
      type        = "Service"
    }
    actions = [
      "s3:PutObject",
    ]
    resources = [
      "${aws_s3_bucket.sponsored_bucket.arn}/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "aws:SourceAccount"
      values   = [data.aws_caller_identity.sponsored_account.account_id]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.sponsored_bucket.arn]
    }
  }

  statement {
    sid = "dandi-api"
    principals {
      type        = "AWS"
      identifiers = [data.aws_iam_user.api.arn]
    }
    actions = [
      "s3:*",
    ]
    resources = [
      "${aws_s3_bucket.sponsored_bucket.arn}/*",
    ]
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
  }
}
