resource "aws_bedrock_guardrail" "this" {
  name                      = var.name
  description               = var.description
  blocked_input_messaging   = var.blocked_input_messaging
  blocked_outputs_messaging = var.blocked_outputs_messaging

  # Content Policy Configuration
  dynamic "content_policy_config" {
    for_each = length(var.content_filters) > 0 ? [1] : []
    content {
      dynamic "filters_config" {
        for_each = var.content_filters
        content {
          input_strength  = filters_config.value.input_strength
          output_strength = filters_config.value.output_strength
          type            = filters_config.value.type
        }
      }
      
      tier_config {
        tier_name = var.content_tier
      }
    }
  }

  # Sensitive Information Policy
  dynamic "sensitive_information_policy_config" {
    for_each = length(var.pii_entities) > 0 || length(var.regex_patterns) > 0 ? [1] : []
    content {
      dynamic "pii_entities_config" {
        for_each = var.pii_entities
        content {
          action         = pii_entities_config.value.action
          input_action   = pii_entities_config.value.input_action
          output_action  = pii_entities_config.value.output_action
          input_enabled  = pii_entities_config.value.input_enabled
          output_enabled = pii_entities_config.value.output_enabled
          type           = pii_entities_config.value.type
        }
      }

      dynamic "regexes_config" {
        for_each = var.regex_patterns
        content {
          action         = regexes_config.value.action
          input_action   = regexes_config.value.input_action
          output_action  = regexes_config.value.output_action
          input_enabled  = regexes_config.value.input_enabled
          output_enabled = regexes_config.value.output_enabled
          description    = regexes_config.value.description
          name           = regexes_config.value.name
          pattern        = regexes_config.value.pattern
        }
      }
    }
  }

  # Topic Policy Configuration
  dynamic "topic_policy_config" {
    for_each = length(var.denied_topics) > 0 ? [1] : []
    content {
      dynamic "topics_config" {
        for_each = var.denied_topics
        content {
          name       = topics_config.value.name
          examples   = topics_config.value.examples
          type       = "DENY"
          definition = topics_config.value.definition
        }
      }
      
      tier_config {
        tier_name = var.topic_tier
      }
    }
  }

  # Word Policy Configuration
  dynamic "word_policy_config" {
    for_each = length(var.managed_word_lists) > 0 || length(var.custom_blocked_words) > 0 ? [1] : []
    content {
      dynamic "managed_word_lists_config" {
        for_each = var.managed_word_lists
        content {
          type = managed_word_lists_config.value
        }
      }
      
      dynamic "words_config" {
        for_each = var.custom_blocked_words
        content {
          text = words_config.value
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_bedrock_guardrail_version" "this" {
  description   = "Version of ${var.name}"
  guardrail_arn = aws_bedrock_guardrail.this.guardrail_arn
  skip_destroy  = var.skip_destroy
}
