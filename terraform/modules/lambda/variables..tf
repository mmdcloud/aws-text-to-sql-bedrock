variable "function_name" {
  type = string
}
variable "role_arn" {}
variable "handler" {}
variable "runtime" {}
variable "s3_bucket" {}
variable "s3_key" {}
variable "env_variables" {
  type = map(string)
}
variable "permissions" {
  type = list(object({
    statement_id = string
    action = string
    principal = string
    source_arn = string
  }))
  default = []
}