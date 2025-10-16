output "target_groups" {
  value = aws_lb_target_group.lb_target_group[*]
}

output "lb_dns_name" {
  value = aws_lb.lb.dns_name
}

output "arn" {
  value = aws_lb.lb.arn
}