output "frontend_url" {
  description = "DNS name of the Frontend ALB"
  value       = module.frontend_lb.dns_name
}

output "cognito_user_pool_id" {
  description = "ID of the Cognito User Pool"
  value       = module.cognito.user_pool_id
}

output "cognito_client_id" {
  description = "ID of the Cognito App Client"
  value       = module.cognito.client_ids[0]
}
