# SSM Validation Commands

After deployment, Terraform generates exact commands:

```bash
terraform output -json ssm_validation_commands
```

Use **AWS Systems Manager > Run Command > AWS-RunShellScript**.

## Generic Command Template

```bash
echo "Testing TARGET_NAME"
ip -br addr
ip route
ping -c 2 TARGET_PRIVATE_IP
curl -m 3 -sS http://TARGET_PRIVATE_IP:8080 || true
```

## What Success Looks Like

For allowed paths:

```text
2 packets transmitted, 2 received
prod validation host responding through aws-tgw-segmentation-lab
```

For blocked paths:

```text
2 packets transmitted, 0 received
curl: (28) Connection timed out
```

## Useful Troubleshooting Commands

```bash
ip -br addr
ip route
curl -m 2 -sS http://169.254.169.254/latest/meta-data/local-ipv4 || true
sudo systemctl status amazon-ssm-agent --no-pager
sudo tail -50 /var/log/amazon/ssm/amazon-ssm-agent.log
sudo tail -50 /var/log/tgw-lab-http.log
```

