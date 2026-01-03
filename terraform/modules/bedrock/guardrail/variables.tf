variable "name" {
  description = "Name of the guardrail"
  type        = string
}

variable "description" {
  description = "Description of the guardrail"
  type        = string
  default     = ""
}

variable "blocked_input_messaging" {
  description = "Message to show when input is blocked"
  type        = string
}

variable "blocked_outputs_messaging" {
  description = "Message to show when output is blocked"
  type        = string
}

variable "content_filters" {
  description = "List of content filters"
  type = list(object({
    type            = string
    input_strength  = string
    output_strength = string
  }))
  default = []
}

variable "content_tier" {
  description = "Content tier (STANDARD or ADVANCED)"
  type        = string
  default     = "STANDARD"
}

variable "pii_entities" {
  description = "List of PII entities to filter"
  type = list(object({
    type           = string
    action         = string
    input_action   = string
    output_action  = string
    input_enabled  = bool
    output_enabled = bool
  }))
  default = []
}

variable "regex_patterns" {
  description = "List of regex patterns to match"
  type = list(object({
    name           = string
    description    = string
    pattern        = string
    action         = string
    input_action   = string
    output_action  = string
    input_enabled  = bool
    output_enabled = bool
  }))
  default = []
}

variable "denied_topics" {
  description = "List of topics to deny"
  type = list(object({
    name       = string
    definition = string
    examples   = list(string)
  }))
  default = []
}

variable "topic_tier" {
  description = "Topic tier (CLASSIC or ADVANCED)"
  type        = string
  default     = "CLASSIC"
}

variable "managed_word_lists" {
  description = "List of managed word lists to use"
  type        = list(string)
  default     = []
}

variable "custom_blocked_words" {
  description = "List of custom words to block"
  type        = list(string)
  default     = []
}

variable "skip_destroy" {
  description = "Skip destruction of guardrail version"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}