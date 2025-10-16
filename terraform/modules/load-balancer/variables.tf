variable "lb_name" {}
variable "lb_is_internal" {}
variable "lb_ip_address_type" {}
variable "load_balancer_type" {}
variable "security_groups" {}
variable "subnets" {}
variable "drop_invalid_header_fields" {}
variable "enable_deletion_protection" {}
variable "target_groups" {
  type = list(object({
    target_group_name                = string
    target_port                      = string
    target_ip_address_type           = string
    target_protocol                  = string
    target_type                      = string
    target_vpc_id                    = string
    health_check_interval            = string
    health_check_path                = string
    health_check_enabled             = string
    health_check_protocol            = string
    health_check_timeout             = string
    health_check_healthy_threshold   = string
    health_check_unhealthy_threshold = string
    health_check_port                = string

  }))
}
variable "listeners" {
  type = list(object({
    listener_port     = string
    listener_protocol = string
    certificate_arn   = string
    default_actions = list(object({
      type             = string
      target_group_arn = string
    }))
  }))
}
