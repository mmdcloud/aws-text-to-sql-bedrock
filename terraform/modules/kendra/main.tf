# -----------------------------------------------------------------
# Kendra INDEX
# -----------------------------------------------------------------
resource "aws_kendra_index" "index" {
  name        = var.index_name
  role_arn    = var.role_arn
  edition     = var.edition
  description = "Kendra search index for internal docs"
  server_side_encryption_configuration {
    kms_key_id = aws_kms_key.kendra.arn
  }
  user_context_policy = "ATTRIBUTE_FILTER"
  capacity_units {
    query_capacity_units = 1
    storage_capacity_units = 1
  }
  tags = {
    Environment = "dev"
  }
}

# -----------------------------------------------------------------
# Kendra Data Sources
# -----------------------------------------------------------------
resource "aws_kendra_data_source" "data_sources" {
  count = length(var.data_sources)
  name       = var.data_sources[count.index].name
  index_id   = aws_kendra_index.index.id
  role_arn   = var.data_sources[count.index].role_arn
  type       = var.data_sources[count.index].type
  configuration {
    template_configuration {
      template = "" 
    }
    s3_configuration {
      bucket_name = aws_s3_bucket.documents.bucket
      inclusion_prefixes = ["docs/"]
    }
  }
  description   = var.data_sources[count.index].description
}