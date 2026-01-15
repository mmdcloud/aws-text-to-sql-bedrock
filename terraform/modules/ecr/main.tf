# ECR repository for storing container images
resource "aws_ecr_repository" "repository" {
  name                 = var.name
  image_tag_mutability = var.image_tag_mutability
  force_delete         = var.force_delete
  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }
  encryption_configuration {
    encryption_type = var.encryption_type
    kms_key         = var.kms_key == "AES256" ? null : var.kms_key
  }
  tags = {
    Name = var.name
  }
}

resource "aws_ecr_lifecycle_policy" "lifecycle_policy" {
  repository = aws_ecr_repository.repository.name
  policy     = var.lifecycle_policy != "" ? var.lifecycle_policy : null
}

resource "null_resource" "push_image_to_ecr" {
  provisioner "local-exec" {
    command = var.bash_command
  }
}