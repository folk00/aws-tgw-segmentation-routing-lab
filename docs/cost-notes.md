# Cost Notes

This lab is designed to avoid the expensive parts that are not needed for TGW routing study.

## What Is Intentionally Avoided

- No NAT Gateways.
- No public IPv4 addresses.
- No Network Firewall.
- No Cloud WAN.
- No Load Balancers.
- No Route 53 Resolver endpoints.

Those services are useful in other labs, but they would distract from the Transit Gateway routing objective.

## Main Cost Drivers

The default lab creates:

- One Transit Gateway.
- Three TGW VPC attachments.
- Three small EC2 validation instances.
- Nine interface VPC endpoints for private SSM access:
  - three endpoints per VPC
  - three VPCs total

For a short study session, the biggest cost driver is usually the interface endpoints plus the TGW attachments. The EC2 instances are small.

## Cheapest Mode

If you only want to study TGW objects and route tables, set:

```hcl
enable_validation_instances = false
```

That removes:

- EC2 validation instances
- IAM instance profile
- EC2 validation security groups

The SSM endpoints are still created in the current version because they are part of the private validation pattern. If you want the absolute cheapest dry infrastructure version later, the endpoint creation can also be made optional.

## Full Study Mode

Keep:

```hcl
enable_validation_instances = true
```

This is the recommended mode for learning because you can prove:

- allowed routing paths
- blocked routing paths
- return path behavior
- security group behavior
- SSM private access without SSH

## Destroy Discipline

Do not leave the lab running overnight.

When done:

```bash
cd terraform
terraform destroy
```

Then verify:

- no TGW remains
- no TGW attachments remain
- no EC2 instances remain
- no interface endpoints remain

