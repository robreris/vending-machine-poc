terraform {
   required_version = ">= 1.6.0"
   required_providers {
     aws = {
       source  = "hashicorp/aws"
       version = "~> 5.0"
     }
   }
}

provider "aws" {
   region = var.region
   profile = var.profile
}

resource "aws_ecr_repository" "repo" {
   name                 = var.name
   image_tag_mutability = "MUTABLE"
   image_scanning_configuration { scan_on_push = true }
   encryption_configuration { encryption_type = "AES256" }
}

resource "aws_ecr_lifecycle_policy" "lifecycle" {
   repository = aws_ecr_repository.repo.name
   policy     = <<JSON
{
   "rules": [
     {
       "rulePriority": 1,
       "description": "Keep last 50 images",
       "selection": {
         "tagStatus": "any",
         "countType": "imageCountMoreThan",
         "countNumber": 50
       },
       "action": { "type": "expire" }
     }
   ]
}
JSON
}

output "repository_url" {
   value = aws_ecr_repository.repo.repository_url
}
