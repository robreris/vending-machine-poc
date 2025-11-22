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

variable "external_services" {
  description = "External services to reconcile ECR/IRSA for (services.yaml)."
  type = list(object({
    name           = string
    ecr_repo_name  = optional(string)
    irsa_role_name = optional(string)
  }))
  default = []
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

  repo_names = toset([for s in local.services : s.repo_name])

  external_services      = var.external_services
  external_repo_names    = toset([for s in local.external_services : lookup(s, "ecr_repo_name", s.name)])
  all_repo_names         = setunion(local.repo_names, local.external_repo_names)
  repo_to_service_lookup = merge(
    { for s in local.services : s.repo_name => s.service },
    { for s in local.external_services : lookup(s, "ecr_repo_name", s.name) => "external:${s.name}" }
  )
}

module "repos" {
  source = "../../modules/microservice-ecr"

  for_each     = local.all_repo_names
  name         = each.key
  force_delete = var.force_delete
}

# Handy output map: service -> repo URL
output "repository_urls" {
  value = { for k, m in module.repos : k => m.repository_url }
}

# Map: repo_name (from its values.yaml) -> service folder (under apps/)
output "repo_to_service" {
  value = local.repo_to_service_lookup
}
