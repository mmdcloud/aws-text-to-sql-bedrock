variable "agent_name" {
  description = "Name of the agent"
  type        = string
}

variable "description" {
  description = "Description of the agent"
  type        = string
  default     = ""
}

variable "agent_resource_role_arn" {
  description = "IAM role ARN for the agent"
  type        = string
}

variable "foundation_model" {
  description = "Foundation model to use"
  type        = string
}

variable "idle_session_ttl_in_seconds" {
  description = "Idle session TTL in seconds"
  type        = number
  default     = 600
}

variable "instruction" {
  description = "Instructions for the agent"
  type        = string
  default     = ""
}

variable "guardrail_identifier" {
  description = "Guardrail identifier"
  type        = string
  default     = null
}

variable "guardrail_version" {
  description = "Guardrail version"
  type        = string
  default     = null
}

variable "knowledge_bases" {
  description = "List of knowledge bases to associate"
  type = list(object({
    knowledge_base_id    = string
    description          = string
    knowledge_base_state = string
  }))
  default = []
}

variable "action_groups" {
  description = "List of action groups"
  type = list(object({
    action_group_name          = string
    agent_version              = string
    description                = string
    skip_resource_in_use_check = bool
    lambda_arn                 = string
    api_schema = object({
      payload         = string
      s3_bucket_name  = string
      s3_object_key   = string
    })
  }))
  default = []
}

variable "prompt_override_configuration" {
  description = "Prompt override configuration"
  type = object({
    prompt_configurations = list(object({
      prompt_type              = string
      prompt_creation_mode     = string
      prompt_state             = string
      base_prompt_template     = string
      inference_configuration  = map(string)
    }))
  })
  default = null
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}