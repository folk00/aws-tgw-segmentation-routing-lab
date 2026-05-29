# TGW Routing Deep Dive

## The Three Pieces People Mix Up

### Attachment

A TGW attachment connects something to the Transit Gateway. In this lab, all attachments are VPC attachments:

- prod VPC attachment
- shared VPC attachment
- dev VPC attachment

An attachment is not enough by itself. It must be associated to a TGW route table.

### Association

Association decides which TGW route table is used when traffic enters the TGW from that attachment.

In this lab:

- prod attachment is associated to the prod TGW route table
- shared attachment is associated to the shared TGW route table
- dev attachment is associated to the dev TGW route table

Think of association as the inbound routing policy for traffic arriving from that attachment.

### Propagation

Propagation advertises an attachment's CIDR into a TGW route table.

In this lab:

- shared propagates into prod route table
- shared propagates into dev route table
- prod propagates into shared route table
- dev propagates into shared route table

But:

- prod does not propagate into dev route table
- dev does not propagate into prod route table

That is the segmentation boundary.

## Blackhole Routes

The lab adds explicit TGW blackhole routes:

- prod TGW route table blackholes `10.30.0.0/16`
- dev TGW route table blackholes `10.10.0.0/16`

This is useful for studying because the denial is visible in the TGW route table. It is not just an accidental missing route.

In production, blackhole routes can be used intentionally to prevent unwanted communication, but they should be documented because they create a very specific routing behavior.

## VPC Route Tables Still Matter

TGW route tables do not replace VPC subnet route tables.

For traffic to leave a VPC through TGW, the subnet route table must point the destination CIDR to TGW.

For example, the prod workload route table contains:

| Destination | Target |
|---|---|
| `10.20.0.0/16` | TGW |
| `10.30.0.0/16` | TGW |

The second route is intentional. It allows the packet to reach TGW, where the TGW blackhole proves that the prod-to-dev path is blocked at the centralized routing layer.

## Common Troubleshooting Checklist

When TGW traffic fails, check in this order:

1. Source subnet route table has destination CIDR pointing to TGW.
2. Source VPC attachment is available.
3. Source attachment is associated to the intended TGW route table.
4. TGW route table has a route to the destination CIDR.
5. Destination VPC attachment is available.
6. Destination subnet route table has return route back to TGW.
7. Security groups and NACLs allow the traffic.
8. OS firewall or application listener is active.

## What This Lab Does Not Cover

This lab intentionally does not include:

- Cloud WAN
- Route 53 Resolver
- Network Firewall
- Site-to-Site VPN
- Direct Connect
- Cross-account RAM sharing

Those are separate concepts. Keeping this lab focused makes TGW easier to understand.

