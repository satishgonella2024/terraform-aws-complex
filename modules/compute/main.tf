# modules/compute/main.tf

# IAM role for EC2 instances
resource "aws_iam_role" "ec2_role" {
  name = "${var.project_name}-${var.environment}-ec2-role"

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
}

# Attach SSM policy to role
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Instance profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "${var.project_name}-${var.environment}-ec2-profile"
  role = aws_iam_role.ec2_role.name
}




# Launch Template
# In modules/compute/main.tf

resource "aws_launch_template" "web" {
  name_prefix   = "${var.project_name}-${var.environment}-web-lt"
  image_id      = var.ami_id
  instance_type = var.instance_type

  vpc_security_group_ids = [var.web_security_group_id]

  user_data = base64encode(<<-EOF
#!/bin/bash
exec > >(tee /var/log/user-data.log | logger -t user-data -s 2>/dev/console) 2>&1
echo "Starting user data script execution..."

# Update system
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Install CloudWatch agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb

# Install and configure Apache
DEBIAN_FRONTEND=noninteractive apt-get install -y apache2 curl

# Configure CloudWatch agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -s -c ssm:/${var.project_name}/${var.environment}/cloudwatch-agent-config

# Start CloudWatch agent
systemctl start amazon-cloudwatch-agent
systemctl enable amazon-cloudwatch-agent

# Fetch instance metadata
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)

# Create a simple health check page
echo "OK" > /var/www/html/health.html

# Create index page with correct metadata
cat <<EOT > /var/www/html/index.html
<!DOCTYPE html>
<html>
<head>
    <title>Instance Info</title>
    <style>
        body { 
            font-family: Arial, sans-serif; 
            margin: 40px; 
            line-height: 1.6;
            color: #333;
        }
        .container { 
            max-width: 800px; 
            margin: 0 auto; 
            padding: 20px;
            box-shadow: 0 0 10px rgba(0,0,0,0.1);
            border-radius: 8px;
        }
        .info { 
            background: #f8f9fa; 
            padding: 20px; 
            border-radius: 5px;
            margin-top: 20px;
        }
        h1 {
            color: #2c3e50;
            border-bottom: 2px solid #eee;
            padding-bottom: 10px;
        }
        .timestamp {
            font-size: 0.9em;
            color: #666;
            margin-top: 20px;
            font-style: italic;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Hello from EC2</h1>
        <div class="info">
            <p><strong>Instance ID:</strong> $INSTANCE_ID</p>
            <p><strong>Availability Zone:</strong> $AZ</p>
            <div class="timestamp">
                <p><strong>Last Updated:</strong> $(date)</p>
            </div>
        </div>
    </div>
</body>
</html>
EOT

# Set correct permissions
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

# Start and enable Apache
systemctl start apache2
systemctl enable apache2

# Verify Apache is running
if ! systemctl is-active apache2 >/dev/null; then
    echo "ERROR: Apache failed to start"
    systemctl status apache2
    exit 1
fi

# Test health check endpoint
if curl -sf http://localhost/health.html >/dev/null; then
    echo "Health check endpoint is responding correctly"
else
    echo "ERROR: Health check endpoint is not responding"
    exit 1
fi

echo "User data script completed successfully"
EOF
)

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${var.project_name}-${var.environment}-web"
    }
  }
}

# Application Load Balancer
resource "aws_lb" "web" {
  name               = "${var.project_name}-${var.environment}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-${var.environment}-alb"
  }
}

# ALB Target Group
resource "aws_lb_target_group" "web" {
  name     = "${var.project_name}-${var.environment}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = 2
    interval            = 15
    matcher             = "200"
    path                =  "/health.html"
    port                = "traffic-port"
    timeout             = 5
    unhealthy_threshold = 2
  }

  tags = {
    Name = "${var.project_name}-${var.environment}-tg"
  }
}

# ALB Listener
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "web" {
  name                = "${var.project_name}-${var.environment}-asg"
  desired_capacity    = var.asg_desired_capacity
  max_size            = var.asg_max_size
  min_size            = var.asg_min_size
  target_group_arns   = [aws_lb_target_group.web.arn]
  vpc_zone_identifier = var.public_subnet_ids

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  dynamic "tag" {
    for_each = var.asg_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# Auto Scaling Policies
resource "aws_autoscaling_policy" "web_scale_up" {
  name                   = "${var.project_name}-${var.environment}-scale-up"
  scaling_adjustment     = 1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_autoscaling_policy" "web_scale_down" {
  name                   = "${var.project_name}-${var.environment}-scale-down"
  scaling_adjustment     = -1
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.web.name
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "web_cpu_high" {
  alarm_name          = "${var.project_name}-${var.environment}-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.scale_up_cpu_threshold
  alarm_description   = "Scale up if CPU > ${var.scale_up_cpu_threshold}% for 10 minutes"
  alarm_actions       = [aws_autoscaling_policy.web_scale_up.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}

resource "aws_cloudwatch_metric_alarm" "web_cpu_low" {
  alarm_name          = "${var.project_name}-${var.environment}-cpu-low"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "300"
  statistic           = "Average"
  threshold           = var.scale_down_cpu_threshold
  alarm_description   = "Scale down if CPU < ${var.scale_down_cpu_threshold}% for 10 minutes"
  alarm_actions       = [aws_autoscaling_policy.web_scale_down.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}
