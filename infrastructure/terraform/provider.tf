terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Using local state for simplicity
  # TODO: Add remote state configuration as an optional step
  # backend "s3" {
  #   bucket = "your-terraform-state-bucket"
  #   key    = "log-analytics/terraform.tfstate"
  #   region = "your-region"
  #   encrypt = true
  # }
}

provider "aws" {
  # These will be set from environment variables by the setup wizard:
  # AWS_ACCESS_KEY_ID
  # AWS_SECRET_ACCESS_KEY
  # AWS_REGION
}

# Additional provider for OpenSearch in a different region if needed
provider "aws" {
  alias = "opensearch"
  # Region will be set based on latency optimization
}
