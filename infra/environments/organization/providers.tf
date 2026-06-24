provider "aws" {
  region              = var.aws_region
  allowed_account_ids = [var.expected_management_account_id]

  default_tags {
    tags = {
      Project   = var.project_name
      ManagedBy = "terraform"
    }
  }
}
