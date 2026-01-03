output "guardrail_id" {
  description = "ID of the guardrail"
  value       = aws_bedrock_guardrail.this.guardrail_id
}

output "guardrail_arn" {
  description = "ARN of the guardrail"
  value       = aws_bedrock_guardrail.this.guardrail_arn
}

output "guardrail_version" {
  description = "Version of the guardrail"
  value       = aws_bedrock_guardrail_version.this.version
}