terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.50.0"
    }
  }
  required_version = ">= 1.3.0"
}

provider "hcloud" {
  token = var.hcloud_token
}
