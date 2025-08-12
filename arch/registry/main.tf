# infra/registry/main.tf
terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

provider "aws" {}

variable "services" {
  description = "Set of app names under apps/"
  type        = set(string)
}

variable "force_delete" {
  description = "Force delete ECR repo even if it contains images"
  type        = bool
  default     = false
}

module "repos" {
  source = "../../modules/microservice-ecr"

  # fan out: one ECR per service
  for_each     = var.services
  name         = each.key
  force_delete = var.force_delete
}

# Handy output map: service -> repo URL
output "repository_urls" {
  value = { for k, m in module.repos : k => m.repository_url }
}
