# Skill 10 — Interview Explanation for the AWS Landing Zone Project

## Skill Purpose
Explain the project clearly in interviews, CVs, GitHub README files, and technical discussions.

## 30-Second Version

I implemented a multi-account AWS landing zone using AWS Organizations, Terraform, centralized logging, IAM roles, SCP guardrails, and standardized networking. The environment separated development, staging, production, security, logging, and shared services into dedicated accounts. This improved isolation, governance, auditability, and repeatability.

## 60-Second Version

I designed and implemented a production-style AWS landing zone using separate AWS accounts for development, staging, production, security, logging, and shared services. I used AWS Organizations to structure accounts into OUs and applied SCP guardrails to prevent risky actions such as disabling CloudTrail, leaving the organization, or deploying resources in unapproved Regions. I centralized CloudTrail logs into a dedicated logging account with S3 encryption, versioning, and restricted access. I also created cross-account IAM roles for platform administration, security audit, and Terraform execution. Networking was standardized with Terraform modules for VPCs, subnets, route tables, flow logs, and shared connectivity. The result was a secure, auditable, and repeatable AWS foundation.

## STAR Interview Version

### Situation
The organization needed a secure AWS foundation that could support multiple environments while keeping production isolated and audit logs protected.

### Task
My responsibility was to design and implement a repeatable multi-account landing zone that could be governed centrally and deployed using infrastructure as code.

### Action
I created an AWS Organizations structure with separate accounts for development, staging, production, security, logging, and shared services. I defined OUs and applied SCP guardrails to restrict risky actions. I implemented centralized CloudTrail logging into a dedicated log archive account, protected with S3 encryption, versioning, and restrictive bucket policies. I designed cross-account IAM roles for Terraform deployment, security auditing, and platform administration. I also created reusable Terraform modules for account baselines, IAM roles, guardrails, logging, and networking standards.

### Result
The landing zone gave the business a secure, scalable, and auditable cloud foundation. Environments were isolated, logging was centralized, security controls were consistent, and infrastructure could be reproduced through Terraform rather than manual setup.

## CV Bullet Points

- Designed and implemented a multi-account AWS landing zone using AWS Organizations, Terraform, SCPs, IAM roles, centralized CloudTrail, and standardized networking.
- Created separate AWS accounts for development, staging, production, security, logging, and shared services to improve isolation, governance, and auditability.
- Built reusable Terraform modules for account baselines, guardrails, centralized logging, cross-account IAM roles, and VPC standards.
- Implemented centralized CloudTrail logging into a dedicated log archive account with encryption, retention, restricted access, and guardrails against tampering.
- Standardized networking across environments using repeatable VPC, subnet, route table, NAT, VPC endpoint, and VPC Flow Log patterns.

## Technical Deep-Dive Questions and Strong Answers

### 1. Why did you use multiple AWS accounts instead of one account with multiple VPCs?

Multiple accounts provide stronger isolation for billing, security, blast radius, access control, and compliance. A production account can have stricter guardrails than development, and a logging account can protect audit evidence from workload administrators.

### 2. Why did you create a dedicated logging account?

A dedicated logging account protects audit logs from being modified or deleted by workload account administrators. It also centralizes evidence for security, compliance, and investigation.

### 3. What is the difference between IAM policies and SCPs?

IAM policies grant permissions to identities or resources. SCPs do not grant permissions; they define the maximum permissions available within accounts or OUs. Even if an IAM policy allows an action, an SCP explicit deny blocks it.

### 4. How did you prevent CloudTrail from being disabled?

I used an organization CloudTrail trail and applied an SCP that denied actions such as `cloudtrail:StopLogging`, `cloudtrail:DeleteTrail`, and `cloudtrail:UpdateTrail` from member accounts.

### 5. How did Terraform deploy across accounts?

Terraform used provider aliases and assumed a dedicated `TerraformExecutionRole` in each target account. Each account or environment had its own remote state file stored in S3 with DynamoDB locking.

### 6. How did you validate the landing zone?

I validated account placement, cross-account role assumption, SCP denial behavior, centralized CloudTrail delivery, networking routes, VPC Flow Logs, Security Hub aggregation, and Terraform drift.

## Common Mistakes to Avoid in Interviews

- Saying SCPs grant permissions.
- Saying the management account hosts workloads.
- Forgetting to mention centralized logging protection.
- Ignoring Terraform remote state and locking.
- Describing networking without CIDR planning.
- Saying production and development have the same controls.
- Not explaining how the setup was validated.

## Final Interview Summary

> The key value of the project was not just creating AWS accounts. It was creating a controlled operating model for AWS: account separation, centralized auditability, least-privilege access, preventive guardrails, consistent networking, and repeatable infrastructure through Terraform.


---

## Updated Interview Explanation with AWS Control Tower

### 30-Second Version with Control Tower

I implemented a multi-account AWS landing zone using AWS Control Tower as the governance baseline and Terraform for customization. The environment separated development, staging, production, security, logging, and shared services into dedicated accounts. Control Tower provided the governed landing zone, account baselines, log archive pattern, audit/security account pattern, and controls, while Terraform handled custom IAM, networking, security configuration, CI/CD validation, and workload baselines.

### Strong Interview Answer

I used AWS Control Tower as the preferred enterprise landing zone accelerator because it provides a consistent governed baseline for multi-account AWS environments. It helped establish the organization structure, log archive and audit/security accounts, account vending model, and governance controls. I then extended that baseline using Terraform modules for custom IAM roles, networking standards, Transit Gateway/shared services, additional SCPs where required, and security-service configuration.

The important design decision was separating what Control Tower owns from what Terraform owns. I avoided managing Control Tower baseline resources directly in Terraform unless ownership was clearly documented. This reduced drift and prevented conflicts with Control Tower lifecycle updates.

### Interview Question: Why not only Terraform?

Terraform is excellent for repeatability, but a production enterprise landing zone also needs a governed operating model. Control Tower provides a prescriptive AWS baseline, account governance, controls, and account factory capabilities. Terraform then becomes the extension layer for custom platform engineering requirements.

### Interview Question: When would you use AFT?

I would use Account Factory for Terraform when the organization needs account vending through a GitOps or Terraform workflow, including account requests, global customizations, account-specific customizations, and CI/CD approval.

