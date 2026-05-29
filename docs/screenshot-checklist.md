# Screenshot Checklist

Use this list after deployment if you want to document the lab for GitHub.

## Must-Have Screenshots

1. **Transit Gateway overview**
   - TGW name and state.
   - Show default association/propagation disabled if visible.

2. **TGW VPC attachments**
   - Three attachments visible.
   - prod, shared, dev.
   - State: `Available`.

3. **TGW route tables list**
   - `tgw-prod-rt`
   - `tgw-shared-rt`
   - `tgw-dev-rt`

4. **prod TGW route table**
   - propagated route to `10.20.0.0/16`
   - blackhole route to `10.30.0.0/16`
   - prod attachment association

5. **dev TGW route table**
   - propagated route to `10.20.0.0/16`
   - blackhole route to `10.10.0.0/16`
   - dev attachment association

6. **shared TGW route table**
   - propagated route to `10.10.0.0/16`
   - propagated route to `10.30.0.0/16`
   - shared attachment association

7. **VPC route tables**
   - prod workload route table routes remote CIDRs to TGW
   - shared workload route table routes remote CIDRs to TGW
   - dev workload route table routes remote CIDRs to TGW

8. **SSM managed nodes**
   - three private instances visible as managed nodes

9. **SSM Run Command allowed path**
   - example: prod to shared succeeds

10. **SSM Run Command blocked path**
   - example: prod to dev fails or times out

## Nice-to-Have Screenshots

- VPC list with human-readable names.
- Subnet list filtered by project name.
- VPC endpoints list showing SSM endpoints.
- EC2 instance details showing no public IPv4 address.
- Security group inbound rules showing ICMP and TCP/8080 from lab CIDRs.

## GitHub Caption Style

Keep captions short and technical:

- "Prod TGW route table allows shared services and blackholes dev."
- "Shared TGW route table receives propagated prod and dev routes."
- "Private validation instances are managed through SSM without public IPs."
- "SSM validation proves prod-to-shared allowed and prod-to-dev blocked."

