# =============================================================================
# Marks Management Module Outputs
# =============================================================================

# RDS Outputs
output "rds_cluster_id" {
  description = "ID of the RDS Aurora cluster"
  value       = aws_rds_cluster.marks_db.id
}

output "rds_cluster_endpoint" {
  description = "Writer endpoint of the RDS Aurora cluster"
  value       = aws_rds_cluster.marks_db.endpoint
}

output "rds_cluster_reader_endpoint" {
  description = "Reader endpoint of the RDS Aurora cluster"
  value       = aws_rds_cluster.marks_db.reader_endpoint
}

output "rds_cluster_port" {
  description = "Port of the RDS Aurora cluster"
  value       = aws_rds_cluster.marks_db.port
}

output "rds_cluster_database_name" {
  description = "Database name of the RDS Aurora cluster"
  value       = aws_rds_cluster.marks_db.database_name
}

output "rds_cluster_master_username" {
  description = "Master username of the RDS Aurora cluster"
  value       = aws_rds_cluster.marks_db.master_username
  sensitive   = true
}

output "rds_cluster_arn" {
  description = "ARN of the RDS Aurora cluster"
  value       = aws_rds_cluster.marks_db.arn
}

output "rds_cluster_resource_id" {
  description = "Resource ID of the RDS Aurora cluster"
  value       = aws_rds_cluster.marks_db.cluster_resource_id
}

# EC2 and Auto Scaling Outputs
output "auto_scaling_group_id" {
  description = "ID of the Auto Scaling Group"
  value       = aws_autoscaling_group.marks_asg.id
}

output "auto_scaling_group_arn" {
  description = "ARN of the Auto Scaling Group"
  value       = aws_autoscaling_group.marks_asg.arn
}

output "auto_scaling_group_name" {
  description = "Name of the Auto Scaling Group"
  value       = aws_autoscaling_group.marks_asg.name
}

output "launch_template_id" {
  description = "ID of the Launch Template"
  value       = aws_launch_template.marks_lt.id
}

output "launch_template_latest_version" {
  description = "Latest version of the Launch Template"
  value       = aws_launch_template.marks_lt.latest_version
}

# Application Load Balancer Outputs
output "alb_id" {
  description = "ID of the Application Load Balancer"
  value       = aws_lb.marks_alb.id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.marks_alb.arn
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.marks_alb.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.marks_alb.zone_id
}

output "alb_hosted_zone_id" {
  description = "Hosted zone ID of the Application Load Balancer"
  value       = aws_lb.marks_alb.zone_id
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.marks_tg.arn
}

output "target_group_name" {
  description = "Name of the target group"
  value       = aws_lb_target_group.marks_tg.name
}

# Security Group Outputs
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb_sg.id
}

output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2_sg.id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds_sg.id
}

# IAM Outputs
output "ec2_instance_profile_name" {
  description = "Name of the EC2 instance profile"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "ec2_role_arn" {
  description = "ARN of the EC2 IAM role"
  value       = aws_iam_role.ec2_role.arn
}

# CloudWatch Outputs
output "log_group_name" {
  description = "Name of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.marks_logs.name
}

output "log_group_arn" {
  description = "ARN of the CloudWatch log group"
  value       = aws_cloudwatch_log_group.marks_logs.arn
}

# Application Configuration Outputs
output "application_url" {
  description = "URL to access the marks management application"
  value       = "http://${aws_lb.marks_alb.dns_name}"
}

output "api_endpoints" {
  description = "API endpoints for the marks management system"
  value = {
    base_url    = "http://${aws_lb.marks_alb.dns_name}"
    health      = "http://${aws_lb.marks_alb.dns_name}/health"
    api_v1      = "http://${aws_lb.marks_alb.dns_name}/api/v1"
    students    = "http://${aws_lb.marks_alb.dns_name}/api/v1/students"
    courses     = "http://${aws_lb.marks_alb.dns_name}/api/v1/courses"
    assignments = "http://${aws_lb.marks_alb.dns_name}/api/v1/assignments"
    grades      = "http://${aws_lb.marks_alb.dns_name}/api/v1/grades"
    reports     = "http://${aws_lb.marks_alb.dns_name}/api/v1/reports"
  }
}

# Database Connection Information
output "database_connection_info" {
  description = "Database connection information for applications"
  value = {
    host     = aws_rds_cluster.marks_db.endpoint
    port     = aws_rds_cluster.marks_db.port
    database = aws_rds_cluster.marks_db.database_name
    username = aws_rds_cluster.marks_db.master_username
  }
  sensitive = true
}

# Monitoring Outputs
output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.name}#dashboards:name=${aws_cloudwatch_dashboard.marks_dashboard.dashboard_name}"
}

# Auto Scaling Configuration
output "auto_scaling_policies" {
  description = "Auto Scaling policy ARNs"
  value = {
    scale_up   = aws_autoscaling_policy.scale_up.arn
    scale_down = aws_autoscaling_policy.scale_down.arn
  }
}

# System Information
output "system_info" {
  description = "System configuration information"
  value = {
    environment           = var.environment
    project_name         = var.project_name
    instance_type        = var.ec2_instance_type
    min_capacity         = var.min_size
    max_capacity         = var.max_size
    desired_capacity     = var.desired_capacity
    database_engine      = "aurora-postgresql"
    database_version     = var.db_engine_version
    multi_az_enabled     = var.enable_multi_az
    backup_retention     = var.backup_retention_period
    monitoring_enabled   = var.enable_detailed_monitoring
  }
}