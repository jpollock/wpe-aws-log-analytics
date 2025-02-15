# Local variables for resource naming and tagging
locals {
  name_prefix = "${var.project_name}-${var.environment}"
  common_tags = merge(var.tags, {
    Environment = var.environment
    Project     = var.project_name
  })
}

# S3 bucket for logs (if creating new)
resource "aws_s3_bucket" "logs" {
  count  = var.create_new_bucket ? 1 : 0
  bucket = var.log_bucket_name

  tags = local.common_tags
}

# OpenSearch Domain
resource "aws_opensearch_domain" "logs" {
  domain_name    = "${local.name_prefix}-logs"
  engine_version = "OpenSearch_2.5"

  cluster_config {
    instance_type          = var.opensearch_instance_type
    instance_count         = var.opensearch_instance_count
    zone_awareness_enabled = var.opensearch_instance_count > 1

    # Enable zone awareness if multiple instances
    dynamic "zone_awareness_config" {
      for_each = var.opensearch_instance_count > 1 ? [1] : []
      content {
        availability_zone_count = 2
      }
    }
  }

  ebs_options {
    ebs_enabled = true
    volume_size = var.opensearch_volume_size
    volume_type = "gp3"
  }

  encrypt_at_rest {
    enabled = true
  }

  node_to_node_encryption {
    enabled = true
  }

  domain_endpoint_options {
    enforce_https       = true
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07"
  }

  advanced_security_options {
    enabled                        = true
    internal_user_database_enabled = true
    master_user_options {
      master_user_name     = "admin"
      master_user_password = random_password.opensearch_master.result
    }
  }

  access_policies = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action = "es:*"
        Resource = "arn:aws:es:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:domain/${local.name_prefix}-logs/*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = ["0.0.0.0/0"]
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# Get current AWS region and account ID
data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Generate secure password for OpenSearch
resource "random_password" "opensearch_master" {
  length  = 16
  special = true
}

# Lambda function for log processing
resource "aws_lambda_function" "log_processor" {
  count = var.alert_email != "" ? 1 : 0  # Only create if alert email is provided

  filename         = "${path.module}/lambda/log_processor.zip"
  function_name    = "${local.name_prefix}-log-processor"
  role            = aws_iam_role.lambda_role.arn
  handler         = "index.handler"
  source_code_hash = filebase64sha256("${path.module}/lambda/log_processor.zip")
  runtime         = "nodejs18.x"
  memory_size     = var.lambda_memory_size
  timeout         = var.lambda_timeout

  environment {
    variables = {
      OPENSEARCH_ENDPOINT = aws_opensearch_domain.logs.endpoint
      OPENSEARCH_PASSWORD = random_password.opensearch_master.result
      LOG_RETENTION_DAYS = var.log_retention_days
      ALERT_EMAIL       = var.alert_email
      ERROR_PATTERNS    = jsonencode(["error", "exception", "fail", "critical", "emergency"])
      SNS_TOPIC_ARN    = aws_sns_topic.alerts.arn
    }
  }

  tags = local.common_tags

  depends_on = [
    aws_opensearch_domain.logs,
    aws_sns_topic.alerts
  ]
}

# S3 event trigger for Lambda
resource "aws_s3_bucket_notification" "logs" {
  count  = var.alert_email != "" ? 1 : 0  # Only create if alert email is provided
  bucket = var.log_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.log_processor[0].arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = "wpe_logs/"
    filter_suffix       = ".gz"
  }

  depends_on = [aws_lambda_permission.s3]
}

# Lambda permission for S3
resource "aws_lambda_permission" "s3" {
  count = var.alert_email != "" ? 1 : 0  # Only create if alert email is provided

  statement_id  = "AllowS3Invoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.log_processor[0].function_name
  principal     = "s3.amazonaws.com"
  source_arn    = "arn:aws:s3:::${var.log_bucket_name}"
}

# SNS Topic for alerts
resource "aws_sns_topic" "alerts" {
  name = "${local.name_prefix}-alerts"
  tags = local.common_tags
}

# SNS Topic subscription for email alerts
resource "aws_sns_topic_subscription" "alerts_email" {
  count = var.alert_email != "" ? 1 : 0  # Only create if alert email is provided

  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# CloudWatch Log Group for Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  count = var.alert_email != "" ? 1 : 0  # Only create if alert email is provided

  name              = "/aws/lambda/${aws_lambda_function.log_processor[0].function_name}"
  retention_in_days = 14
  tags             = local.common_tags
}

# Budget alert
resource "aws_budgets_budget" "monthly" {
  count = var.enable_cost_alerts && var.alert_email != "" ? 1 : 0  # Only create if alerts enabled and email provided

  name              = "${local.name_prefix}-monthly-budget"
  budget_type       = "COST"
  limit_amount      = var.monthly_budget_amount
  limit_unit        = "USD"
  time_period_start = "2024-01-01_00:00"
  time_unit         = "MONTHLY"

  notification {
    comparison_operator = "GREATER_THAN"
    threshold          = 80
    threshold_type     = "PERCENTAGE"
    notification_type  = "ACTUAL"
    subscriber_email_addresses = [var.alert_email]
  }
}

# Output important information
output "opensearch_endpoint" {
  value = aws_opensearch_domain.logs.endpoint
}

output "opensearch_dashboard_endpoint" {
  value = "${aws_opensearch_domain.logs.endpoint}/_dashboards"
}

output "sns_topic_arn" {
  value = aws_sns_topic.alerts.arn
}

output "opensearch_password" {
  value     = random_password.opensearch_master.result
  sensitive = true
}
