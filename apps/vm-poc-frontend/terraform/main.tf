terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

provider "aws" {}

module "ecr" {
  source = "../../../modules/microservice-ecr"
  #name   = "vm-poc-frontend"
  name   = yamldecode(file("${path.root}/../values.yaml")).name                     
}

output "repository_url" {
  value = module.ecr.repository_url
}
