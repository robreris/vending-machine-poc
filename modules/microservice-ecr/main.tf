variable "name" {
  description = "Name of the microservice (ECR repo name)"
  type        = string
}

variable "aws_region" {
  type    = string
  default = "us-east-1"
}

variable "enable_image_scanning" {
  type    = bool
  default = true
}

variable "immutable_tags" {
  type    = bool
  default = true
}

variable "retain_images" {
  type    = number
  default = 30
}

variable "force_delete" {
  type    = bool
  default = false
}

resource "aws_ecr_repository" "this" {
  name                 = var.name
  image_tag_mutability = var.immutable_tags ? "IMMUTABLE" : "MUTABLE"
  force_delete         = var.force_delete

  image_scanning_configuration {
    scan_on_push = var.enable_image_scanning
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

resource "aws_ecr_lifecycle_policy" "keep_recent" {
  repository = aws_ecr_repository.this.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1,
      description  = "Keep last ${var.retain_images} images",
      action       = { type = "expire" },
      selection    = {
        tagStatus   = "any",
        countType   = "imageCountMoreThan",
        countNumber = var.retain_images
      }
    }]
  })
}

output "repository_url" {
  value = aws_ecr_repository.this.repository_url
}
