provider "kubernetes" {
  config_path    = "generated/kubeconfig"
  config_context = "admin@talos"
}

terraform {
  backend "s3" {
    bucket         = "your-bucket-name"
    key            = "terraform.tfstate"
    region         = "eu-west-1"
    access_key     = ""
    secret_key     = ""
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
}
