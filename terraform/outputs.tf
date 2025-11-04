output "frontend_url" {
  value = module.frontend_lb.dns_name
}

output "backend_url" {
  value = module.backend_lb.dns_name
}