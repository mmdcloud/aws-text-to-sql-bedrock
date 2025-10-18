variable "name" {}
variable "username_attributes" {}
variable "auto_verified_attributes" {}
variable "password_minimum_length" {}
variable "password_require_lowercase" {}
variable "password_require_numbers" {}
variable "password_require_symbols" {}
variable "password_require_uppercase" {}
variable "schema" {
  type = list(object({
    attribute_data_type = string
    name                = string
    required            = bool
  }))
}
variable "verification_message_template_default_email_option" {}
variable "verification_email_subject" {}
variable "verification_email_message" {}
variable "user_pool_clients" {
  type = list(object({
    name                                 = string
    generate_secret                      = bool
    explicit_auth_flows                  = list(string)
    allowed_oauth_flows_user_pool_client = bool
    allowed_oauth_flows                  = list(string)
    allowed_oauth_scopes                 = list(string)
    callback_urls                        = list(string)
    logout_urls                          = list(string)
    supported_identity_providers         = list(string)
  }))
}