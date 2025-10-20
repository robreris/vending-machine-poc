terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.0" }
  }
}

provider "aws" {}

variable "cluster_name" {
  description = "EKS cluster name used to discover the OIDC identity provider."
  type        = string
  default     = "vending-machine-poc"
}

variable "table_name" {
  description = "Name for the shared DynamoDB products table."
  type        = string
  default     = "vm-poc-products"
}

variable "service_accounts" {
  description = "Service accounts (namespace/name) that require read access to the products table."
  type = list(object({
    namespace = string
    name      = string
  }))
  default = [
    {
      namespace = "default"
      name      = "vm-poc-backend-fortiflex"
    }
  ]
}

locals {
  service_account_subjects = [
    for sa in var.service_accounts : "system:serviceaccount:${sa.namespace}:${sa.name}"
  ]
}

data "aws_region" "current" {}

data "aws_eks_cluster" "this" {
  name = var.cluster_name
}

data "aws_iam_openid_connect_provider" "cluster" {
  url = data.aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_dynamodb_table" "products" {
  name         = var.table_name
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  tags = {
    Service     = "vm-poc-products"
    Environment = "poc"
  }
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [data.aws_iam_openid_connect_provider.cluster.arn]
    }

    condition {
      test     = "StringEquals"
      variable = "${replace(data.aws_eks_cluster.this.identity[0].oidc[0].issuer, "https://", "")}:sub"
      values   = local.service_account_subjects
    }
  }
}

data "aws_iam_policy_document" "dynamodb_read" {
  statement {
    sid     = "AllowReadProductsTable"
    actions = [
      "dynamodb:BatchGetItem",
      "dynamodb:DescribeTable",
      "dynamodb:GetItem",
      "dynamodb:Query",
      "dynamodb:Scan"
    ]
    resources = [aws_dynamodb_table.products.arn]
  }
}

resource "aws_iam_policy" "dynamodb_read" {
  name   = "${var.table_name}-read"
  policy = data.aws_iam_policy_document.dynamodb_read.json

  tags = {
    Service     = "vm-poc-products"
    Environment = "poc"
  }
}

resource "aws_iam_role" "dynamodb_reader" {
  name               = "${var.table_name}-reader"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json

  tags = {
    Service     = "vm-poc-products"
    Environment = "poc"
  }
}

resource "aws_iam_role_policy_attachment" "attach_read" {
  role       = aws_iam_role.dynamodb_reader.name
  policy_arn = aws_iam_policy.dynamodb_read.arn
}

output "products_table_name" {
  description = "Name of the shared products table."
  value       = aws_dynamodb_table.products.name
}

output "products_table_arn" {
  description = "ARN of the shared products table."
  value       = aws_dynamodb_table.products.arn
}

output "dynamodb_reader_role_arn" {
  description = "IAM role that pods should assume (via IRSA) to read the products table."
  value       = aws_iam_role.dynamodb_reader.arn
}

output "dynamodb_service_accounts" {
  description = "Service accounts authorized for the IRSA trust policy."
  value       = local.service_account_subjects
}
