resource "aws_bedrockagent_knowledge_base" "this" {
  name        = var.name
  description = var.description
  role_arn    = var.role_arn

  knowledge_base_configuration {
    vector_knowledge_base_configuration {
      embedding_model_arn = var.embedding_model_arn
    }
    type = "VECTOR"
  }

  storage_configuration {
    type = var.storage_type

    dynamic "pinecone_configuration" {
      for_each = var.storage_type == "PINECONE" ? [var.pinecone_config] : []
      content {
        connection_string      = pinecone_configuration.value.connection_string
        credentials_secret_arn = pinecone_configuration.value.credentials_secret_arn
        namespace              = pinecone_configuration.value.namespace

        field_mapping {
          text_field     = pinecone_configuration.value.text_field
          metadata_field = pinecone_configuration.value.metadata_field
        }
      }
    }

    dynamic "opensearch_serverless_configuration" {
      for_each = var.storage_type == "OPENSEARCH_SERVERLESS" ? [var.opensearch_config] : []
      content {
        collection_arn    = opensearch_serverless_configuration.value.collection_arn
        vector_index_name = opensearch_serverless_configuration.value.vector_index_name

        field_mapping {
          text_field     = opensearch_serverless_configuration.value.text_field
          metadata_field = opensearch_serverless_configuration.value.metadata_field
          vector_field   = opensearch_serverless_configuration.value.vector_field
        }
      }
    }
  }

  tags = var.tags
}

resource "aws_bedrockagent_data_source" "this" {
  for_each = { for idx, ds in var.data_sources : ds.name => ds }

  knowledge_base_id = aws_bedrockagent_knowledge_base.this.id
  name              = each.value.name
  description       = each.value.description

  data_source_configuration {
    type = each.value.type

    dynamic "s3_configuration" {
      for_each = each.value.type == "S3" ? [1] : []
      content {
        bucket_arn         = each.value.bucket_arn
        inclusion_prefixes = each.value.inclusion_prefixes
      }
    }
  }
}