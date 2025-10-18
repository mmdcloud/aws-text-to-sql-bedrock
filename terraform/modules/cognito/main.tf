# Cognito User Pool
resource "aws_cognito_user_pool" "user_pool" {
  name                     = var.name
  username_attributes      = var.username_attributes
  auto_verified_attributes = var.auto_verified_attributes

  password_policy {
    minimum_length    = var.password_minimum_length
    require_lowercase = var.password_require_lowercase
    require_numbers   = var.password_require_numbers
    require_symbols   = var.password_require_symbols
    require_uppercase = var.password_require_uppercase
  }
  dynamic "schema" {
    for_each = var.schema
    content {
      attribute_data_type = schema.value.attribute_data_type
      name                = schema.value.name
      required            = schema.value.required
    }
  }
  verification_message_template {
    default_email_option = var.verification_message_template_default_email_option
    email_subject        = var.verification_email_subject
    email_message        = var.verification_email_message
  }
}

# Cognito User Pool Client
resource "aws_cognito_user_pool_client" "user_pool_client" {
  count                                = length(var.user_pool_clients)
  user_pool_id                         = aws_cognito_user_pool.user_pool.id
  name                                 = var.user_pool_clients[count.index].name
  generate_secret                      = var.user_pool_clients[count.index].generate_secret
  explicit_auth_flows                  = var.user_pool_clients[count.index].explicit_auth_flows
  allowed_oauth_flows_user_pool_client = var.user_pool_clients[count.index].allowed_oauth_flows_user_pool_client
  allowed_oauth_flows                  = var.user_pool_clients[count.index].allowed_oauth_flows
  allowed_oauth_scopes                 = var.user_pool_clients[count.index].allowed_oauth_scopes
  callback_urls                        = var.user_pool_clients[count.index].callback_urls
  logout_urls                          = var.user_pool_clients[count.index].logout_urls
  supported_identity_providers         = var.user_pool_clients[count.index].supported_identity_providers
}