# =============================================================================
# EC2 Auto Scaling Configuration for Marks Management
# =============================================================================

# Data source for latest Amazon Linux 2 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM Role for EC2 Instances
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-marks-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-ec2-role"
    Component = "marks"
    Purpose   = "ec2-permissions"
  })
}

# IAM Policy for EC2 Instances
resource "aws_iam_role_policy" "ec2_policy" {
  name = "${var.project_name}-${var.environment}-marks-ec2-policy"
  role = aws_iam_role.ec2_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret"
        ]
        Resource = aws_secretsmanager_secret.db_credentials.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:DescribeParameters"
        ]
        Resource = "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter/${var.project_name}/${var.environment}/*"
      },
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/aws/ec2/${var.project_name}-${var.environment}-marks*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:PutMetricData",
          "cloudwatch:GetMetricStatistics",
          "cloudwatch:ListMetrics"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:DescribeKey"
        ]
        Resource = var.kms_key_arn != "" ? var.kms_key_arn : "*"
      },
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject"
        ]
        Resource = "arn:aws:s3:::${var.project_name}-${var.environment}-deployment-artifacts/*"
      }
    ]
  })
}

# Attach CloudWatch Agent policy
resource "aws_iam_role_policy_attachment" "cloudwatch_agent" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Attach SSM managed instance policy
resource "aws_iam_role_policy_attachment" "ssm_managed_instance" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# EC2 Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-marks-ec2-profile"
  role = aws_iam_role.ec2_role.name

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-ec2-profile"
    Component = "marks"
    Purpose   = "ec2-instance-profile"
  })
}

# User Data Script for EC2 Instances
locals {
  user_data = base64encode(templatefile("${path.module}/user_data.sh", {
    project_name    = var.project_name
    environment     = var.environment
    app_port        = var.app_port
    node_env        = var.node_env
    db_secret_arn   = aws_secretsmanager_secret.db_credentials.arn
    region          = data.aws_region.current.name
    log_group_name  = aws_cloudwatch_log_group.marks_logs.name
  }))
}

# Launch Template
resource "aws_launch_template" "marks_lt" {
  name_prefix   = "${var.project_name}-${var.environment}-marks-"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = var.ec2_instance_type
  key_name      = var.ec2_key_pair_name != "" ? var.ec2_key_pair_name : null

  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2_profile.name
  }

  user_data = local.user_data

  # Enable detailed monitoring
  monitoring {
    enabled = var.enable_detailed_monitoring
  }

  # Instance metadata options
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
    instance_metadata_tags      = "enabled"
  }

  # EBS optimization
  ebs_optimized = true

  # Block device mappings
  block_device_mappings {
    device_name = "/dev/xvda"
    ebs {
      volume_type           = "gp3"
      volume_size           = 20
      encrypted             = true
      kms_key_id           = var.kms_key_arn != "" ? var.kms_key_arn : null
      delete_on_termination = true
    }
  }

  tag_specifications {
    resource_type = "instance"
    tags = merge(var.tags, {
      Name      = "${var.project_name}-${var.environment}-marks-instance"
      Component = "marks"
      Purpose   = "application-server"
    })
  }

  tag_specifications {
    resource_type = "volume"
    tags = merge(var.tags, {
      Name      = "${var.project_name}-${var.environment}-marks-volume"
      Component = "marks"
      Purpose   = "application-storage"
    })
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-launch-template"
    Component = "marks"
    Purpose   = "launch-configuration"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "marks_asg" {
  name                = "${var.project_name}-${var.environment}-marks-asg"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.marks_tg.arn]
  health_check_type   = var.health_check_type
  health_check_grace_period = var.health_check_grace_period

  min_size         = var.min_size
  max_size         = var.max_size
  desired_capacity = var.desired_capacity

  launch_template {
    id      = aws_launch_template.marks_lt.id
    version = "$Latest"
  }

  # Instance refresh configuration
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup       = 300
    }
  }

  # Termination policies
  termination_policies = ["OldestInstance", "Default"]

  # Enable instance protection for production
  protect_from_scale_in = var.environment == "prod" ? true : false

  tag {
    key                 = "Name"
    value               = "${var.project_name}-${var.environment}-marks-asg"
    propagate_at_launch = false
  }

  dynamic "tag" {
    for_each = var.tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
    ignore_changes       = [desired_capacity]
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "scale_up" {
  name                   = "${var.project_name}-${var.environment}-marks-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = var.scale_up_cooldown
  autoscaling_group_name = aws_autoscaling_group.marks_asg.name
  policy_type           = "SimpleScaling"
}

resource "aws_autoscaling_policy" "scale_down" {
  name                   = "${var.project_name}-${var.environment}-marks-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown              = var.scale_down_cooldown
  autoscaling_group_name = aws_autoscaling_group.marks_asg.name
  policy_type           = "SimpleScaling"
}

# Target Tracking Scaling Policy for CPU
resource "aws_autoscaling_policy" "cpu_target_tracking" {
  name                   = "${var.project_name}-${var.environment}-marks-cpu-target-tracking"
  autoscaling_group_name = aws_autoscaling_group.marks_asg.name
  policy_type           = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = var.cpu_target_value
  }
}

# CloudWatch Alarms for Auto Scaling
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-marks-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.marks_asg.name
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-high-cpu-alarm"
    Component = "marks"
    Purpose   = "auto-scaling-monitoring"
  })
}

resource "aws_cloudwatch_metric_alarm" "low_cpu" {
  alarm_name          = "${var.project_name}-${var.environment}-marks-low-cpu"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = "20"
  alarm_description   = "This metric monitors ec2 cpu utilization"
  alarm_actions       = [aws_autoscaling_policy.scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.marks_asg.name
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-low-cpu-alarm"
    Component = "marks"
    Purpose   = "auto-scaling-monitoring"
  })
}

# CloudWatch Log Group for Application Logs
resource "aws_cloudwatch_log_group" "marks_logs" {
  name              = "/aws/ec2/${var.project_name}-${var.environment}-marks"
  retention_in_days = var.log_retention_days

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-logs"
    Component = "marks"
    Purpose   = "application-logging"
  })
}

