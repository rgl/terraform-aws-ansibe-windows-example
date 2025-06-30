# see https://github.com/hashicorp/terraform
terraform {
  required_version = "1.12.2"
  required_providers {
    # see https://registry.terraform.io/providers/hashicorp/random
    # see https://github.com/hashicorp/terraform-provider-random
    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }
    # see https://registry.terraform.io/providers/hashicorp/aws
    # see https://github.com/hashicorp/terraform-provider-aws
    aws = {
      source  = "hashicorp/aws"
      version = "6.0.0"
    }
    # see https://registry.terraform.io/providers/ansible/ansible
    # see https://github.com/ansible/terraform-provider-ansible
    ansible = {
      source  = "ansible/ansible"
      version = "1.3.0"
    }
  }
}

provider "aws" {
  region = var.region
  default_tags {
    tags = {
      Project     = "terraform-aws-ansibe-windows-example"
      Environment = "test"
    }
  }
}
