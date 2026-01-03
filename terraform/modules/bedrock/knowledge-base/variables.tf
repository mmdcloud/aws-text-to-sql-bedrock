variable "name" {
  description = "Name of the knowledge base"
  type        = string
}

variable "description" {
  description = "Description of the knowledge base"
  type        = string
  default     = ""
}

variable "role_arn" {
  description = "IAM role ARN for the knowledge base"
  type        = string
}

variable "embedding_model_arn" {
  description = "ARN of the embedding model"
  type        = string
}

variable "storage_type" {
  description = "Type of storage (PINECONE, OPENSEARCH_SERVERLESS, RDS)"
  type        = string
  default     = "PINECONE"
}

variable "pinecone_config" {
  description = "Pinecone configuration"
  type = object({
    connection_string      = string
    credentials_secret_arn = string
    namespace              = string
    text_field             = string
    metadata_field         = string
  })
  default = null
}

variable "opensearch_config" {
  description = "OpenSearch Serverless configuration"
  type = object({
    collection_arn    = string
    vector_index_name = string
    text_field        = string
    metadata_field    = string
    vector_field      = string
  })
  default = null
}

variable "data_sources" {
  description = "List of data sources"
  type = list(object({
    name               = string
    description        = string
    type               = string
    bucket_arn         = string
    inclusion_prefixes = list(string)
    exclusion_prefixes = list(string)
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}