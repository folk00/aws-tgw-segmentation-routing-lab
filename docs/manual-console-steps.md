# Manual Console Steps

This file explains how the Terraform lab maps to manual AWS Console work.

Do not use this as the primary deployment method unless you want to practice the console flow.

## 1. Create Three VPCs

Create:

| VPC | CIDR |
|---|---:|
| `prod-app-vpc` | `10.10.0.0/16` |
| `shared-services-vpc` | `10.20.0.0/16` |
| `dev-app-vpc` | `10.30.0.0/16` |

Enable DNS support and DNS hostnames.

## 2. Create One Private Subnet Per VPC

Example:

| VPC | Subnet |
|---|---:|
| prod | `10.10.10.0/24` |
| shared | `10.20.10.0/24` |
| dev | `10.30.10.0/24` |

Use the same Availability Zone for the simple lab version.

## 3. Create Route Tables

Create one workload route table per VPC and associate it to the workload subnet.

At this stage, each route table has only the local route.

## 4. Create Transit Gateway

Recommended settings:

- DNS support: enabled
- VPN ECMP: enabled
- Default route table association: disabled
- Default route table propagation: disabled
- Amazon side ASN: `64512`

Disabling default association and propagation forces you to understand the routing design.

## 5. Create Three TGW Route Tables

Create:

- `tgw-prod-rt`
- `tgw-shared-rt`
- `tgw-dev-rt`

## 6. Create VPC Attachments

Create one VPC attachment per VPC.

Use the workload subnet in each VPC.

Wait until each attachment is `Available`.

## 7. Associate Attachments

Associate:

| Attachment | TGW route table |
|---|---|
| prod attachment | `tgw-prod-rt` |
| shared attachment | `tgw-shared-rt` |
| dev attachment | `tgw-dev-rt` |

## 8. Configure Propagation

Add propagation:

| Attachment that propagates | Into TGW route table |
|---|---|
| shared | prod |
| shared | dev |
| prod | shared |
| dev | shared |

Do not propagate prod into dev.

Do not propagate dev into prod.

## 9. Add Blackhole Routes

In `tgw-prod-rt`:

- `10.30.0.0/16` -> blackhole

In `tgw-dev-rt`:

- `10.10.0.0/16` -> blackhole

## 10. Add VPC Routes to TGW

In prod workload route table:

- `10.20.0.0/16` -> TGW
- `10.30.0.0/16` -> TGW

In shared workload route table:

- `10.10.0.0/16` -> TGW
- `10.30.0.0/16` -> TGW

In dev workload route table:

- `10.10.0.0/16` -> TGW
- `10.20.0.0/16` -> TGW

## 11. Add Optional Validation Hosts

For private SSM validation without NAT:

1. Create SSM interface endpoints in each VPC:
   - `ssm`
   - `ssmmessages`
   - `ec2messages`
2. Create an IAM role with `AmazonSSMManagedInstanceCore`.
3. Launch one private EC2 instance per VPC.
4. Attach the IAM role.
5. Confirm the instances appear in Systems Manager.

## 12. Validate

Allowed:

- prod to shared
- dev to shared
- shared to prod
- shared to dev

Blocked:

- prod to dev
- dev to prod

