variable "name" {
  type = string
}
variable "image_tag_mutability" {
  type = string
}
variable "force_delete" {
  type = bool
}
variable "scan_on_push" {
  type = bool
}
variable "bash_command" {
  type = string
}
variable "lifecycle_policy" {
  type = string
  default = null
}
variable "encryption_type" {
  type = string
  default = null
}
variable "kms_key" {
  type = string
  default = null
}