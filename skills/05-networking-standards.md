# Skill 05 — Networking Standards for Multi-Account AWS

## Skill Purpose
Design consistent, secure, and scalable network foundations across development, staging, production, shared services, security, and logging accounts.

## What You Must Know

- VPC design
- CIDR planning
- Public, private, and isolated subnets
- Route tables
- Internet Gateway
- NAT Gateway
- VPC endpoints
- Transit Gateway
- VPC peering
- Private hosted zones
- Security groups and NACLs
- VPC Flow Logs
- Centralized ingress and egress patterns

## CIDR Allocation Example

| Account | CIDR |
|---|---|
| Development | 10.10.0.0/16 |
| Staging | 10.20.0.0/16 |
| Production | 10.30.0.0/16 |
| Shared Services | 10.40.0.0/16 |
| Security | 10.50.0.0/16 |
| Logging | 10.60.0.0/16 |

## Standard VPC Pattern

```text
VPC /16
├── Public Subnets
│   ├── AZ-A /24
│   ├── AZ-B /24
│   └── AZ-C /24
├── Private Application Subnets
│   ├── AZ-A /24
│   ├── AZ-B /24
│   └── AZ-C /24
└── Isolated Data Subnets
    ├── AZ-A /24
    ├── AZ-B /24
    └── AZ-C /24
```

## Networking Rules

- Production must be multi-AZ.
- Workloads should run in private subnets by default.
- Databases should run in isolated subnets.
- Internet-facing resources must be explicitly approved.
- Public subnets are mainly for load balancers, NAT gateways, and approved edge services.
- VPC Flow Logs must be enabled.
- Use VPC endpoints to reduce public internet dependency.
- Avoid overlapping CIDRs.
- Use shared services account for network hub if using Transit Gateway.

## Terraform Resources to Learn

- `aws_vpc`
- `aws_subnet`
- `aws_internet_gateway`
- `aws_nat_gateway`
- `aws_route_table`
- `aws_route_table_association`
- `aws_security_group`
- `aws_vpc_endpoint`
- `aws_ec2_transit_gateway`
- `aws_ec2_transit_gateway_vpc_attachment`
- `aws_flow_log`
- `aws_route53_zone`

## Implementation Tasks

1. Define global CIDR allocation.
2. Build reusable VPC module.
3. Add subnet calculation logic.
4. Add NAT Gateway strategy.
5. Add route table standards.
6. Add VPC endpoints for common AWS services.
7. Add Flow Logs.
8. Add Transit Gateway or peering if required.
9. Test connectivity between accounts.
10. Document routing and traffic flow.

## Validation Checks

```bash
aws ec2 describe-vpcs
aws ec2 describe-subnets
aws ec2 describe-route-tables
aws ec2 describe-flow-logs
```

## Common Mistakes

- Overlapping CIDR blocks.
- Putting application servers in public subnets.
- Not enabling VPC Flow Logs.
- Creating inconsistent network patterns per environment.
- Overusing VPC peering when Transit Gateway is more appropriate.
- Forgetting route propagation and security group rules.

## Interview Talking Point

> I created a standard VPC module so development, staging, and production had consistent network layouts. Each environment had public, private, and isolated subnet tiers across multiple Availability Zones, with VPC Flow Logs enabled and shared connectivity controlled through a central networking pattern.
