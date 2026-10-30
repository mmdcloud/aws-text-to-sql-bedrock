output "endpoint" {
  value = aws_db_instance.db.endpoint
}

output "name" {
  value = aws_db_instance.db.db_name
}

output "identifier" {
  value = aws_db_instance.db.identifier
}