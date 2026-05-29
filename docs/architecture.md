# Architecture

## Goal

This lab demonstrates a common enterprise pattern:

- Application networks should not all talk to each other by default.
- Shared services can be reachable from multiple segments.
- Routing control is centralized in AWS Transit Gateway route tables.

The lab is intentionally regional. Cloud WAN is not used here because the purpose is to isolate the Transit Gateway behavior.

## Resource Model

| Segment | VPC name | CIDR | Workload subnet | TGW route table |
|---|---|---:|---:|---|
| prod | `prod-app-vpc` | `10.10.0.0/16` | `10.10.10.0/24` | `prod` |
| shared | `shared-services-vpc` | `10.20.0.0/16` | `10.20.10.0/24` | `shared` |
| dev | `dev-app-vpc` | `10.30.0.0/16` | `10.30.10.0/24` | `dev` |

Each VPC has:

- One private workload subnet.
- One workload route table.
- One TGW VPC attachment.
- Three private SSM interface endpoints:
  - `ssm`
  - `ssmmessages`
  - `ec2messages`
- One private EC2 validation host when `enable_validation_instances = true`.

There are no NAT Gateways and no public IPs in the default design.

## Traffic Intent

| Source | Destination | Expected | Why |
|---|---|---|---|
| prod | shared | Allowed | shared attachment propagates into prod TGW route table |
| dev | shared | Allowed | shared attachment propagates into dev TGW route table |
| shared | prod | Allowed | prod attachment propagates into shared TGW route table |
| shared | dev | Allowed | dev attachment propagates into shared TGW route table |
| prod | dev | Blocked | prod TGW route table has blackhole route to dev CIDR |
| dev | prod | Blocked | dev TGW route table has blackhole route to prod CIDR |

## Route Flow

For `prod -> shared`:

1. Prod EC2 sends traffic to `10.20.10.x`.
2. Prod subnet route table sends `10.20.0.0/16` to TGW.
3. Prod TGW attachment is associated to the `prod` TGW route table.
4. The `prod` TGW route table has a propagated route to `10.20.0.0/16` through the shared attachment.
5. Shared VPC receives the traffic.
6. Shared return traffic uses its own subnet route table and the shared TGW route table to return to prod.

For `prod -> dev`:

1. Prod EC2 sends traffic to `10.30.10.x`.
2. Prod subnet route table sends `10.30.0.0/16` to TGW.
3. Prod TGW attachment is associated to the `prod` TGW route table.
4. The `prod` TGW route table has an explicit blackhole for `10.30.0.0/16`.
5. Traffic is dropped by TGW.

## Why This Matters

In many production issues, teams check only the VPC route table and miss the TGW route table association. The VPC can correctly point to TGW and traffic can still fail if the attachment is associated to the wrong TGW route table or if propagation is missing.

This lab makes that behavior visible.

