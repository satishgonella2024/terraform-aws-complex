# Networking outputs
output "vpc_id" {
  description = "ID of the created VPC"
  value       = module.networking.vpc_id
}

output "public_subnet_ids" {
  description = "IDs of public subnets"
  value       = module.networking.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of private subnets"
  value       = module.networking.private_subnet_ids
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway"
  value       = module.networking.internet_gateway_id
}

output "nat_gateway_id" {
  description = "ID of the NAT Gateway"
  value       = module.networking.nat_gateway_id
}

output "public_route_table_id" {
  description = "ID of the public route table"
  value       = module.networking.public_route_table_id
}

output "private_route_table_id" {
  description = "ID of the private route table"
  value       = module.networking.private_route_table_id
}

# Security outputs
output "security_group_ids" {
  description = "IDs of all security groups"
  value = {
    alb = module.security.alb_security_group_id
    web = module.security.web_security_group_id
    app = module.security.app_security_group_id
    db  = module.security.db_security_group_id
  }
}

# Compute outputs
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.compute.alb_dns_name
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = module.compute.launch_template_id
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = module.compute.autoscaling_group_name
}