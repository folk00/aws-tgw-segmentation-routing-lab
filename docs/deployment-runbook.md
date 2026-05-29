# Deployment Runbook

## Prerequisites

- Terraform `>= 1.6`
- AWS CLI configured with permissions to create:
  - VPCs and subnets
  - Transit Gateway
  - TGW route tables and VPC attachments
  - EC2 instances
  - IAM role and instance profile for SSM
  - Interface VPC endpoints
  - Security groups
- An AWS Region that supports Transit Gateway and SSM interface endpoints.

Default region:

```bash
us-east-1
```

## Deploy

```bash
cd terraform
terraform init
terraform plan -out plan.out
terraform apply plan.out
```

## What Terraform Creates First

The high-level order is:

1. VPCs and private workload subnets.
2. VPC route tables.
3. Transit Gateway.
4. TGW route tables.
5. TGW VPC attachments.
6. TGW route table associations.
7. TGW route propagations.
8. Explicit TGW blackhole routes.
9. VPC routes pointing remote CIDRs to TGW.
10. SSM interface endpoints.
11. Private EC2 validation hosts.

Terraform handles dependency ordering, but this sequence is the clean mental model.

## Validate Resource State

After `terraform apply`, check:

```bash
terraform output transit_gateway_id
terraform output vpc_ids
terraform output tgw_attachment_ids
terraform output tgw_route_table_ids
terraform output validation_private_ips
```

In AWS Console:

1. Go to **VPC > Transit Gateways** and confirm the TGW is `Available`.
2. Go to **Transit Gateway Attachments** and confirm the three VPC attachments are `Available`.
3. Go to **Transit Gateway Route Tables** and check:
   - prod route table has propagated/shared route and blackhole to dev.
   - dev route table has propagated/shared route and blackhole to prod.
   - shared route table has propagated prod and dev routes.
4. Go to **VPC > Route Tables** and confirm workload route tables point remote CIDRs to TGW.
5. Go to **Systems Manager > Fleet Manager** or **Managed Nodes** and confirm the EC2 instances appear as managed nodes.

## Run Validation

Use:

```bash
terraform output -json ssm_validation_commands
```

Each output item gives:

- source instance ID
- target private IP
- expected result
- command to run

Run the command through:

**AWS Systems Manager > Run Command > AWS-RunShellScript**

Target the source instance ID from the output.

## Destroy

When done:

```bash
cd terraform
terraform destroy
```

From PowerShell you can also run:

```powershell
.\scripts\destroy.ps1
```

Wait until destroy completes. TGW attachments and interface endpoints can take a few minutes to delete.

Important: the destroy depends on the local `terraform.tfstate` file in the `terraform`
folder. The state file is intentionally ignored by Git and should not be pushed, but keep
it locally until the lab has been destroyed.

## If Destroy Fails

Common causes:

- TGW attachment is still deleting.
- A route still references TGW.
- A VPC endpoint is still deleting.

Run:

```bash
terraform destroy
```

again after a few minutes. Avoid deleting resources manually unless Terraform is blocked and you know which dependency is stuck.
