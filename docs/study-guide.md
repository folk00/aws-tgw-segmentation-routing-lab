# Study Guide

## Concepts to Know

### Transit Gateway

A regional AWS routing hub that connects VPCs, VPNs and Direct Connect gateways. In this lab, it connects three VPCs.

### TGW VPC Attachment

The object that connects a VPC to the Transit Gateway. A VPC attachment uses one subnet per selected Availability Zone.

### TGW Route Table Association

The TGW route table that an attachment uses when traffic enters the TGW through that attachment.

This is one of the most important points:

> Association is about which route table is used by incoming traffic from an attachment.

### TGW Route Propagation

The process of inserting an attachment's CIDR into a TGW route table.

This is different from association.

### Blackhole Route

A route that intentionally drops matching traffic.

This lab uses blackhole routes to make prod/dev isolation explicit.

### VPC Route Table

The subnet route table inside each VPC. It decides whether traffic leaves the VPC toward TGW.

Both sides are required:

- VPC route table sends traffic to TGW.
- TGW route table sends or drops traffic after it enters TGW.

## Console Areas to Inspect

### VPC Route Tables

Check each workload route table.

Expected:

- Prod route table points shared and dev CIDRs to TGW.
- Dev route table points shared and prod CIDRs to TGW.
- Shared route table points prod and dev CIDRs to TGW.

### Transit Gateway Attachments

Check that each attachment is `Available`.

Expected:

- prod VPC attachment
- shared VPC attachment
- dev VPC attachment

### Transit Gateway Route Tables

This is the main study area.

Expected:

- `prod` TGW route table:
  - route to shared
  - blackhole to dev
- `dev` TGW route table:
  - route to shared
  - blackhole to prod
- `shared` TGW route table:
  - route to prod
  - route to dev

### Systems Manager

The EC2 instances are private. Use SSM Run Command instead of SSH.

Expected:

- all three instances show as managed nodes
- `AWS-RunShellScript` can run validation commands

## How to Explain the Design

Short version:

> I built a regional TGW segmentation lab with separate TGW route tables for prod, dev and shared services. Prod and dev can both reach shared services, but prod and dev are isolated from each other through explicit TGW blackhole routes and controlled propagation. Validation is done with private EC2 instances through SSM, without NAT Gateways or public IPs.

More technical version:

> Each VPC has a TGW attachment. The attachment association controls which TGW route table is used when traffic enters TGW. Shared services propagates into prod and dev route tables, while prod and dev propagate only into the shared route table. Prod and dev do not propagate into each other's route tables, and the lab adds explicit blackhole routes to make that segmentation visible. VPC subnet route tables still need routes to TGW for the remote CIDRs, so the design demonstrates both VPC-side and TGW-side routing.

## What to Avoid Saying

Do not say this is Cloud WAN. It is not.

Do not say this is hybrid networking. It is pure regional TGW with VPC attachments.

Do not say TGW automatically routes everything after attachments are created. It does not when route table association and propagation are explicitly controlled.

