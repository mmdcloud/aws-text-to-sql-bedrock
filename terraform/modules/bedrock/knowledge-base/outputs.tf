output "knowledge_base_id" {
  description = "ID of the knowledge base"
  value       = aws_bedrockagent_knowledge_base.this.id
}

output "knowledge_base_arn" {
  description = "ARN of the knowledge base"
  value       = aws_bedrockagent_knowledge_base.this.arn
}

output "data_source_ids" {
  description = "Map of data source names to IDs"
  value       = { for k, v in aws_bedrockagent_data_source.this : k => v.id }
}