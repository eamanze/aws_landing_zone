output "trail_id" {
  description = "Terraform-owned manual-mode organization trail ID, or null when disabled."
  value       = try(aws_cloudtrail.organization[0].id, null)
}

output "trail_arn" {
  description = "Terraform-owned manual-mode organization trail ARN, or null when disabled."
  value       = try(aws_cloudtrail.organization[0].arn, null)
}

output "home_region" {
  description = "Provider Region where the manual-mode organization trail is managed."
  value       = try(aws_cloudtrail.organization[0].home_region, null)
}
