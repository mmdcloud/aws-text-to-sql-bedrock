variable "role_arn" {
  description = "The ARN of the IAM role that Kendra will assume"
  type        = string
}

variable "index_name" {
  description = "The name of the Kendra index"
  type        = string
}

variable "edition" {
  description = "The edition of the Kendra index"
  type        = string
  validation {
    condition     = contains(["DEVELOPER_EDITION", "ENTERPRISE_EDITION", "GEN_AI_ENTERPRISE_EDITION"], var.edition)
    error_message = "The 'kendra_edition' must be either 'DEVELOPER_EDITION' or 'ENTERPRISE_EDITION' or 'GEN_AI_ENTERPRISE_EDITION'."
  }
}

variable "data_sources" {
  type = list(object({
    name        = string
    type        = string
    role_arn    = string
    description = string
  }))
}