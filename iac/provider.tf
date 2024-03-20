terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  cloud {
    organization = "brignano"
    workspaces {
      name = "aws-config"
    }
  }
}

provider "aws" {
  region = local.region
}
