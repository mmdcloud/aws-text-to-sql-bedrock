# Load Balancer Creation
resource "aws_lb" "lb" {
  name                       = var.lb_name
  internal                   = var.lb_is_internal
  ip_address_type            = var.lb_ip_address_type
  load_balancer_type         = var.load_balancer_type
  security_groups            = var.security_groups
  drop_invalid_header_fields = var.drop_invalid_header_fields
  subnets                    = var.subnets
  enable_deletion_protection = var.enable_deletion_protection
  tags = {
    Name = var.lb_name
  }
}

# Target Groups
resource "aws_lb_target_group" "lb_target_group" {
  count           = length(var.target_groups)
  name            = var.target_groups[count.index].target_group_name
  port            = var.target_groups[count.index].target_port
  ip_address_type = var.target_groups[count.index].target_ip_address_type
  protocol        = var.target_groups[count.index].target_protocol
  target_type     = var.target_groups[count.index].target_type
  vpc_id          = var.target_groups[count.index].target_vpc_id
  health_check {
    interval            = var.target_groups[count.index].health_check_interval
    path                = var.target_groups[count.index].health_check_path
    enabled             = var.target_groups[count.index].health_check_enabled
    protocol            = var.target_groups[count.index].health_check_protocol
    timeout             = var.target_groups[count.index].health_check_timeout
    healthy_threshold   = var.target_groups[count.index].health_check_healthy_threshold
    unhealthy_threshold = var.target_groups[count.index].health_check_unhealthy_threshold
    port                = var.target_groups[count.index].health_check_port
  }
  tags = {
    Name = var.target_groups[count.index].target_group_name
  }
}

# Listeners
resource "aws_lb_listener" "lb_listener" {
  count             = length(var.listeners)
  load_balancer_arn = aws_lb.lb.arn
  port              = var.listeners[count.index].listener_port
  protocol          = var.listeners[count.index].listener_protocol
  certificate_arn   = var.listeners[count.index].certificate_arn != "" ? var.listeners[count.index].certificate_arn : null
  dynamic "default_action" {
    for_each = var.listeners[count.index].default_actions
    content {
      type             = default_action.value["type"]
      target_group_arn = default_action.value["target_group_arn"]
    }
  }
}
