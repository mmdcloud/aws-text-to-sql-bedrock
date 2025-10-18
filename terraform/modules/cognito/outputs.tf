output "arn" {
  value = aws_cognito_user_pool.user_pool.arn
}

output "user_pool_id" {
  value = aws_cognito_user_pool.user_pool.id
}

output "user_pool_arn" {
  value = aws_cognito_user_pool.user_pool.arn
}

output "client_ids" {
  value = [for client in aws_cognito_user_pool_client.user_pool_client : client.id]  
}