terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
  cloud {
    organization = "brignano"
    workspaces {
      # todo: add project and tags
      name = "aws-config"
    }
  }
}

provider "aws" {
  region = local.region
  default_tags {
    tags = {
      Environment = "Production"
      Owner       = "Anthony Brignano"
      Project     = "aws-config"
      Repository  = "https://www.github.com/brignano/aws"
      Terraform   = "https://app.terraform.io/app/brignano/workspaces/aws-config"
    }
  }
}
