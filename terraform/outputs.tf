output "frontend_url" {
  value = module.frontend_lb.lb_dns_name
}

output "backend_url" {
  value = module.backend_lb.lb_dns_name
}