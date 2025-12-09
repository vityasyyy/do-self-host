terraform {
  required_version = ">= 1.5.0"
  backend "s3" {
    endpoint                    = "https://sgp1.digitaloceanspaces.com"
    bucket                      = "vityasy-bucket" # REPLACE with your actual bucket name
    key                         = "terraform.tfstate"
    region                      = "us-east-1" # Leave as us-east-1 (Required for DO Spaces compatibility)
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_requesting_account_id  = true
    skip_region_validation      = true
  }
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.5"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "digitalocean" { token = var.do_token }
provider "cloudflare" { api_token = var.cloudflare_api_token }
