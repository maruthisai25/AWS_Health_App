# =============================================================================
# Application Load Balancer for Marks Management System
# =============================================================================

# Application Load Balancer
resource "aws_lb" "marks_alb" {
  name               = "${var.project_name}-${var.environment}-marks-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets           = var.public_subnet_ids

  # ALB Configuration
  enable_deletion_protection       = var.enable_deletion_protection
  idle_timeout                    = var.idle_timeout
  enable_http2                    = var.enable_http2
  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing

  # Access Logs (optional)
  dynamic "access_logs" {
    for_each = var.environment == "prod" ? [1] : []
    content {
      bucket  = aws_s3_bucket.alb_logs[0].bucket
      prefix  = "alb-logs"
      enabled = true
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-alb"
    Component = "marks"
    Purpose   = "load-balancer"
  })
}

# S3 Bucket for ALB Access Logs (Production only)
resource "aws_s3_bucket" "alb_logs" {
  count  = var.environment == "prod" ? 1 : 0
  bucket = "${var.project_name}-${var.environment}-marks-alb-logs-${random_id.bucket_suffix[0].hex}"

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-alb-logs"
    Component = "marks"
    Purpose   = "load-balancer-logs"
  })
}

resource "random_id" "bucket_suffix" {
  count       = var.environment == "prod" ? 1 : 0
  byte_length = 4
}

resource "aws_s3_bucket_versioning" "alb_logs" {
  count  = var.environment == "prod" ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_encryption" "alb_logs" {
  count  = var.environment == "prod" ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm     = var.kms_key_arn != "" ? "aws:kms" : "AES256"
        kms_master_key_id = var.kms_key_arn != "" ? var.kms_key_arn : null
      }
    }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "alb_logs" {
  count  = var.environment == "prod" ? 1 : 0
  bucket = aws_s3_bucket.alb_logs[0].id

  rule {
    id     = "log_lifecycle"
    status = "Enabled"

    expiration {
      days = 90
    }

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

# ALB Target Group
resource "aws_lb_target_group" "marks_tg" {
  name     = "${var.project_name}-${var.environment}-marks-tg"
  port     = var.app_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  # Health Check Configuration
  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 10
    interval            = 30
    path                = "/health"
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  # Target Group Attributes
  target_type                       = "instance"
  deregistration_delay             = 300
  slow_start                       = 30
  load_balancing_algorithm_type    = "round_robin"

  # Stickiness (disabled by default)
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = false
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-tg"
    Component = "marks"
    Purpose   = "load-balancer-target-group"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# ALB Listener - HTTP
resource "aws_lb_listener" "marks_http" {
  load_balancer_arn = aws_lb.marks_alb.arn
  port              = "80"
  protocol          = "HTTP"

  # Default action - forward to target group
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.marks_tg.arn
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-http-listener"
    Component = "marks"
    Purpose   = "load-balancer-listener"
  })
}

# ALB Listener - HTTPS (if SSL certificate is available)
resource "aws_lb_listener" "marks_https" {
  count             = var.environment == "prod" ? 1 : 0
  load_balancer_arn = aws_lb.marks_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS-1-2-2017-01"
  certificate_arn   = aws_acm_certificate.marks_cert[0].arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.marks_tg.arn
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-https-listener"
    Component = "marks"
    Purpose   = "load-balancer-https-listener"
  })
}

# SSL Certificate (Production only)
resource "aws_acm_certificate" "marks_cert" {
  count             = var.environment == "prod" ? 1 : 0
  domain_name       = "marks.${var.project_name}.com"
  validation_method = "DNS"

  subject_alternative_names = [
    "*.marks.${var.project_name}.com"
  ]

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-cert"
    Component = "marks"
    Purpose   = "ssl-certificate"
  })
}

# Listener Rules for different paths
resource "aws_lb_listener_rule" "api_v1" {
  listener_arn = aws_lb_listener.marks_http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.marks_tg.arn
  }

  condition {
    path_pattern {
      values = ["/api/v1/*"]
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-api-rule"
    Component = "marks"
    Purpose   = "load-balancer-rule"
  })
}

resource "aws_lb_listener_rule" "health_check" {
  listener_arn = aws_lb_listener.marks_http.arn
  priority     = 200

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.marks_tg.arn
  }

  condition {
    path_pattern {
      values = ["/health"]
    }
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-health-rule"
    Component = "marks"
    Purpose   = "load-balancer-health-rule"
  })
}

# CloudWatch Alarms for ALB
resource "aws_cloudwatch_metric_alarm" "alb_target_response_time" {
  alarm_name          = "${var.project_name}-${var.environment}-marks-alb-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "1"
  alarm_description   = "This metric monitors ALB target response time"
  alarm_actions       = []

  dimensions = {
    LoadBalancer = aws_lb.marks_alb.arn_suffix
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-alb-response-time-alarm"
    Component = "marks"
    Purpose   = "load-balancer-monitoring"
  })
}

resource "aws_cloudwatch_metric_alarm" "alb_unhealthy_hosts" {
  alarm_name          = "${var.project_name}-${var.environment}-marks-alb-unhealthy-hosts"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "UnHealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "0"
  alarm_description   = "This metric monitors unhealthy hosts behind ALB"
  alarm_actions       = []

  dimensions = {
    TargetGroup  = aws_lb_target_group.marks_tg.arn_suffix
    LoadBalancer = aws_lb.marks_alb.arn_suffix
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-alb-unhealthy-hosts-alarm"
    Component = "marks"
    Purpose   = "load-balancer-health-monitoring"
  })
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx_errors" {
  alarm_name          = "${var.project_name}-${var.environment}-marks-alb-5xx-errors"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HTTPCode_ELB_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Sum"
  threshold           = "10"
  alarm_description   = "This metric monitors 5XX errors from ALB"
  alarm_actions       = []

  dimensions = {
    LoadBalancer = aws_lb.marks_alb.arn_suffix
  }

  tags = merge(var.tags, {
    Name      = "${var.project_name}-${var.environment}-marks-alb-5xx-errors-alarm"
    Component = "marks"
    Purpose   = "load-balancer-error-monitoring"
  })
}

# CloudWatch Dashboard for ALB Metrics
resource "aws_cloudwatch_dashboard" "marks_dashboard" {
  dashboard_name = "${var.project_name}-${var.environment}-marks-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.marks_alb.arn_suffix],
            [".", "TargetResponseTime", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "ALB Metrics"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", aws_lb_target_group.marks_tg.arn_suffix, "LoadBalancer", aws_lb.marks_alb.arn_suffix],
            [".", "UnHealthyHostCount", ".", ".", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "Target Health"
          period  = 300
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 12
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.marks_asg.name],
            ["AWS/ApplicationELB", "ActiveConnectionCount", "LoadBalancer", aws_lb.marks_alb.arn_suffix],
            [".", "NewConnectionCount", ".", "."]
          ]
          view    = "timeSeries"
          stacked = false
          region  = data.aws_region.current.name
          title   = "System Performance"
          period  = 300
        }
      }
    ]
  })
}