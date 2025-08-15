terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

variable "force_delete" {
  description = "Force delete ECR repo even if it contains images."
  type        = bool
  default     = true
}

provider "aws" {}

locals {
  value_files = fileset("${path.root}/../../apps", "*/values.yaml")  
  services = [
    for rel in local.value_files : {
      service   = split("/", rel)[0]
      repo_name = yamldecode(file("${path.root}/../../apps/${rel}")).name
    }
    if split("/", rel)[0] != "charts"
  ]
  repo_names = toset([ for s in local.services : s.repo_name ])
}

module "repos" {
  source = "../../modules/microservice-ecr"

  for_each     = local.repo_names
  name         = each.key
  force_delete = var.force_delete
}

# Handy output map: service -> repo URL
output "repository_urls" {
  value = { for k, m in module.repos : k => m.repository_url }
}

# Map: repo_name (from its values.yaml) -> service folder (under apps/)
output "repo_to_service" {
  value = {
    for s in local.services : s.repo_name => s.service
  }
}
