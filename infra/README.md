# Infrastructure

This directory will contain deployable Terraform modules, environment roots, policy documents, and shared version templates.

The directory itself is not a Terraform root. Do not run `terraform plan` or `terraform apply` from `infra/`.

No deployable resources are present in the initial scaffold. Each implementation must document ownership boundaries with AWS Control Tower before adding resources.
