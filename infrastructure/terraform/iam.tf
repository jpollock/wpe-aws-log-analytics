# IAM role for Lambda function
resource "aws_iam_role" "lambda_role" {
  name = "${local.name_prefix}-lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Lambda basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

# Custom policy for Lambda to access S3, OpenSearch, and SNS
resource "aws_iam_role_policy" "lambda_custom" {
  name = "${local.name_prefix}-lambda-custom-policy"
  role = aws_iam_role.lambda_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.log_bucket_name}",
          "arn:aws:s3:::${var.log_bucket_name}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "es:ESHttp*",
          "es:DescribeElasticsearchDomain",
          "es:ListDomainNames"
        ]
        Resource = [
          aws_opensearch_domain.logs.arn,
          "${aws_opensearch_domain.logs.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "sns:Publish"
        ]
        Resource = [
          aws_sns_topic.alerts.arn
        ]
      }
    ]
  })
}

# OpenSearch access policy
resource "aws_opensearch_domain_policy" "main" {
  domain_name = aws_opensearch_domain.logs.domain_name

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_role.arn
        }
        Action = "es:*"
        Resource = "${aws_opensearch_domain.logs.arn}/*"
      },
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = "es:*"
        Resource = "${aws_opensearch_domain.logs.arn}/*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = ["0.0.0.0/0"] # Will be restricted by the setup wizard
          }
        }
      }
    ]
  })
}

# S3 bucket policy (if creating new bucket)
resource "aws_s3_bucket_policy" "logs" {
  count  = var.create_new_bucket ? 1 : 0
  bucket = aws_s3_bucket.logs[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowLambdaAccess"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.lambda_role.arn
        }
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.logs[0].arn,
          "${aws_s3_bucket.logs[0].arn}/*"
        ]
      }
    ]
  })
}

# Additional IAM role for OpenSearch dashboard access
resource "aws_iam_role" "dashboard_access" {
  name = "${local.name_prefix}-dashboard-access"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "opensearch.amazonaws.com"
        }
      }
    ]
  })

  tags = local.common_tags
}

# Policy for dashboard access
resource "aws_iam_role_policy" "dashboard_access" {
  name = "${local.name_prefix}-dashboard-access-policy"
  role = aws_iam_role.dashboard_access.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "es:ESHttp*"
        ]
        Resource = [
          aws_opensearch_domain.logs.arn,
          "${aws_opensearch_domain.logs.arn}/*"
        ]
      }
    ]
  })
}

# Output the role ARNs for reference
output "lambda_role_arn" {
  value = aws_iam_role.lambda_role.arn
}

output "dashboard_role_arn" {
  value = aws_iam_role.dashboard_access.arn
}
