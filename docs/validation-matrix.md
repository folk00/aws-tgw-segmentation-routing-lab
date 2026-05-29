# Validation Matrix

The validation hosts are private EC2 instances. They have no public IP and use private SSM interface endpoints.

Each instance runs a simple HTTP service on port `8080` through user data.

## Expected Results

| Test | Source | Destination | Expected | Validation |
|---|---|---|---|---|
| `prod_to_shared` | prod EC2 | shared EC2 | Pass | `ping` and `curl :8080` should work |
| `dev_to_shared` | dev EC2 | shared EC2 | Pass | `ping` and `curl :8080` should work |
| `shared_to_prod` | shared EC2 | prod EC2 | Pass | `ping` and `curl :8080` should work |
| `shared_to_dev` | shared EC2 | dev EC2 | Pass | `ping` and `curl :8080` should work |
| `prod_to_dev` | prod EC2 | dev EC2 | Fail | TGW blackhole route blocks it |
| `dev_to_prod` | dev EC2 | prod EC2 | Fail | TGW blackhole route blocks it |

## Why Ping and Curl

`ping` proves basic L3 reachability.

`curl` to port `8080` proves:

- routing works
- security group allows TCP/8080
- return path works
- application listener is reachable

## Commands

Get the generated commands:

```bash
terraform output -json ssm_validation_commands
```

Example command shape:

```bash
echo 'prod_to_shared: expected allowed'
ping -c 2 10.20.10.10
curl -m 3 -sS http://10.20.10.10:8080 || true
```

For blocked tests, the `ping` and `curl` should fail or time out.

## If an Allowed Test Fails

Check:

1. Source instance is managed by SSM.
2. Target instance is running.
3. Target security group allows ICMP and TCP/8080 from lab CIDRs.
4. Source VPC route table points destination CIDR to TGW.
5. Source TGW attachment is associated to the correct TGW route table.
6. TGW route table has propagated route to the destination attachment.
7. Destination VPC route table has return route to source CIDR through TGW.

## If a Blocked Test Passes

Check:

1. Prod TGW route table has blackhole to `10.30.0.0/16`.
2. Dev TGW route table has blackhole to `10.10.0.0/16`.
3. Prod and dev attachments are not accidentally propagating into each other's TGW route tables.
4. The source attachment association points to the intended TGW route table.

