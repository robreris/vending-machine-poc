terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

provider "aws" {}

locals {
  value_files = fileset("${path.root}/../../apps", "*/values.yaml")

  services = [
    for rel in local.value_files : {
      service   = split("/", rel)[0]
      repo_name = element(
        split("/", yamldecode(file("${path.root}/../../apps/${rel}")).image.repository),
        -1
      )
    }
    if split("/", rel)[0] != "charts"
  ]

  repo_names = toset([ for s in local.services : s.repo_name ])
}

module "repos" {
  source = "../../modules/microservice-ecr"

  for_each     = local.repo_names
  name         = each.key
}

# Handy output map: service -> repo URL
output "repository_urls" {
  value = { for k, m in module.repos : k => m.repository_url }
}

output "repo_to_service" {
  value = {
    for s in local.services : s.repo_name => s.service
  }
}
