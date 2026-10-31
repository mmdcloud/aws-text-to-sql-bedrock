variable "region" {
  type = string
}

variable "public_subnets" {
  type        = list(string)
  description = "Public Subnet CIDR values"
}

variable "private_subnets" {
  type        = list(string)
  description = "Private Subnet CIDR values"
}

variable "database_subnets" {
  type        = list(string)
  description = "Database Subnet CIDR values"
}

variable "azs" {
  type        = list(string)
  description = "Availability Zones"
}

variable "alarm_email" {
  type        = string
  description = "Alarm Email"
}

variable "domain_name" {
  type        = string
  description = "Domain Name"
}

variable "pinecone_connection_string" {
  type        = string
  description = "Pinecone index connection string"
  sensitive   = true
}

variable "enable_bedrock_agent" {
  type        = bool
  description = "Whether to create Bedrock Agent Classic. Defaults to false because AWS placed Bedrock Agents Classic in Maintenance Mode for new accounts."
  default     = false
}

variable "bedrock_agent_id" {
  type        = string
  description = "Existing Bedrock Agent ID if available"
  default     = ""
}