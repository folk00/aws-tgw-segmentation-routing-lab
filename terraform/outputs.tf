output "transit_gateway_id" {
  description = "Transit Gateway ID."
  value       = aws_ec2_transit_gateway.core.id
}

output "vpc_ids" {
  description = "VPC IDs by segment."
  value = {
    for key, vpc in aws_vpc.this : key => vpc.id
  }
}

output "tgw_attachment_ids" {
  description = "TGW VPC attachment IDs by segment."
  value = {
    for key, attachment in aws_ec2_transit_gateway_vpc_attachment.this : key => attachment.id
  }
}

output "tgw_route_table_ids" {
  description = "TGW route table IDs by segment."
  value = {
    for key, route_table in aws_ec2_transit_gateway_route_table.this : key => route_table.id
  }
}

output "validation_instance_ids" {
  description = "Private validation instance IDs by segment."
  value = var.enable_validation_instances ? {
    for key, instance in aws_instance.validation : key => instance.id
  } : {}
}

output "validation_private_ips" {
  description = "Private validation instance IP addresses by segment."
  value = var.enable_validation_instances ? {
    for key, instance in aws_instance.validation : key => instance.private_ip
  } : {}
}

output "expected_reachability" {
  description = "Expected traffic behavior for validation."
  value       = local.validation_pairs
}

output "ssm_validation_commands" {
  description = "Copy/paste these commands into SSM Run Command against the source instance."
  value = var.enable_validation_instances ? {
    for name, test in local.validation_pairs : name => {
      source_instance_id = aws_instance.validation[test.source].id
      target_private_ip  = aws_instance.validation[test.target].private_ip
      expected_result    = test.expect
      command            = "echo '${name}: expected ${test.expect}'; ping -c 2 ${aws_instance.validation[test.target].private_ip}; curl -m 3 -sS http://${aws_instance.validation[test.target].private_ip}:8080 || true"
    }
  } : {}
}

