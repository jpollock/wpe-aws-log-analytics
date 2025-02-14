# General Settings
variable "project_name" {
  description = "Name of the log analytics project"
  type        = string
  default     = "log-analytics"
}

variable "environment" {
  description = "Environment (e.g., prod, dev, staging)"
  type        = string
  default     = "prod"
}

# OpenSearch Settings
variable "opensearch_instance_type" {
  description = "OpenSearch instance type"
  type        = string
  default     = "t3.small.search" # Smallest instance for cost optimization
}

variable "opensearch_instance_count" {
  description = "Number of OpenSearch instances"
  type        = number
  default     = 1
}

variable "opensearch_volume_size" {
  description = "Size of OpenSearch EBS volume in GB"
  type        = number
  default     = 10
}

# Log Retention Settings
variable "log_retention_days" {
  description = "Number of days to retain logs"
  type        = number
  default     = 30
}

# Alert Settings
variable "alert_email" {
  description = "Email address for alerts"
  type        = string
}

variable "enable_critical_alerts" {
  description = "Enable alerts for critical errors"
  type        = bool
  default     = true
}

variable "enable_security_alerts" {
  description = "Enable alerts for security events"
  type        = bool
  default     = true
}

variable "enable_performance_alerts" {
  description = "Enable alerts for performance issues"
  type        = bool
  default     = true
}

# S3 Settings
variable "log_bucket_name" {
  description = "Name of the S3 bucket containing logs"
  type        = string
}

variable "create_new_bucket" {
  description = "Whether to create a new S3 bucket"
  type        = bool
  default     = false
}

# Lambda Settings
variable "lambda_memory_size" {
  description = "Memory allocation for Lambda functions in MB"
  type        = number
  default     = 128
}

variable "lambda_timeout" {
  description = "Lambda function timeout in seconds"
  type        = number
  default     = 60
}

# Network Settings
variable "vpc_id" {
  description = "VPC ID for OpenSearch deployment"
  type        = string
  default     = null # Will use default VPC if not specified
}

variable "subnet_ids" {
  description = "Subnet IDs for OpenSearch deployment"
  type        = list(string)
  default     = [] # Will use default subnets if not specified
}

# Tags
variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    ManagedBy = "terraform"
    Project   = "log-analytics"
  }
}

# Cost Control
variable "enable_cost_alerts" {
  description = "Enable alerts for cost thresholds"
  type        = bool
  default     = true
}

variable "monthly_budget_amount" {
  description = "Monthly budget amount in USD"
  type        = number
  default     = 100
}

# Dashboard Settings
variable "timezone" {
  description = "Timezone for dashboard displays"
  type        = string
  default     = "UTC"
}

variable "dashboard_refresh_interval" {
  description = "Dashboard refresh interval in seconds"
  type        = number
  default     = 300
}

# Error Pattern Settings
variable "error_patterns" {
  description = "Patterns to match for error detection"
  type        = list(string)
  default     = [
    "error",
    "exception",
    "fail",
    "critical",
    "emergency"
  ]
}

# Rate Limiting Settings
variable "rate_limit_period" {
  description = "Period for rate limit checks in minutes"
  type        = number
  default     = 5
}

variable "rate_limit_threshold" {
  description = "Number of events before rate limiting triggers"
  type        = number
  default     = 100
}
