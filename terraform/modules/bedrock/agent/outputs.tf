output "agent_id" {
  description = "ID of the agent"
  value       = aws_bedrockagent_agent.this.agent_id
}

output "agent_arn" {
  description = "ARN of the agent"
  value       = aws_bedrockagent_agent.this.agent_arn
}

output "agent_version" {
  description = "Version of the agent"
  value       = aws_bedrockagent_agent.this.agent_version
}