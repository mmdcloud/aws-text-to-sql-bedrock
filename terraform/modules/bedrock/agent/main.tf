resource "aws_bedrockagent_agent" "this" {
  agent_name                  = var.agent_name
  description                 = var.description
  agent_resource_role_arn     = var.agent_resource_role_arn
  foundation_model            = var.foundation_model
  idle_session_ttl_in_seconds = var.idle_session_ttl_in_seconds
  instruction                 = var.instruction

  dynamic "guardrail_configuration" {
    for_each = var.guardrail_identifier != null ? [1] : []
    content {
      guardrail_identifier = var.guardrail_identifier
      guardrail_version    = var.guardrail_version
    }
  }

  dynamic "prompt_override_configuration" {
    for_each = var.prompt_override_configuration != null ? [var.prompt_override_configuration] : []
    content {
      dynamic "prompt_configurations" {
        for_each = prompt_override_configuration.value.prompt_configurations
        content {
          prompt_type              = prompt_configurations.value.prompt_type
          prompt_creation_mode     = prompt_configurations.value.prompt_creation_mode
          prompt_state             = prompt_configurations.value.prompt_state
          base_prompt_template     = prompt_configurations.value.base_prompt_template
          inference_configuration  = prompt_configurations.value.inference_configuration
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_bedrockagent_agent_knowledge_base_association" "this" {
  for_each = { for idx, kb in var.knowledge_bases : kb.knowledge_base_id => kb }

  agent_id             = aws_bedrockagent_agent.this.agent_id
  description          = each.value.description
  knowledge_base_id    = each.value.knowledge_base_id
  knowledge_base_state = each.value.knowledge_base_state
}

resource "aws_bedrockagent_agent_action_group" "this" {
  for_each = { for idx, ag in var.action_groups : ag.action_group_name => ag }

  action_group_name          = each.value.action_group_name
  agent_id                   = aws_bedrockagent_agent.this.agent_id
  agent_version              = each.value.agent_version
  description                = each.value.description
  skip_resource_in_use_check = each.value.skip_resource_in_use_check

  dynamic "action_group_executor" {
    for_each = each.value.lambda_arn != null ? [1] : []
    content {
      lambda = each.value.lambda_arn
    }
  }

  dynamic "api_schema" {
    for_each = each.value.api_schema != null ? [each.value.api_schema] : []
    content {
      payload = api_schema.value.payload
      s3 {
        s3_bucket_name = api_schema.value.s3_bucket_name
        s3_object_key  = api_schema.value.s3_object_key
      }
    }
  }
}