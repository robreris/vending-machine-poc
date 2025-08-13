terraform {
  backend "s3" {
    bucket         = "vm-poc-tfstate-bucket"
    key            = "registry/vmpoc.tfstate" 
    region         = "us-east-1"
    dynamodb_table = "tf-state-vm-poc-table"
    encrypt        = true
  }
}
