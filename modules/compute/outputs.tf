# modules/compute/outputs.tf

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.web.dns_name
}

output "autoscaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.web.name
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.web.id
}

output "target_group_arn" {
  description = "ARN of the Target Group"
  value       = aws_lb_target_group.web.arn
}