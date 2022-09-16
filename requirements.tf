terraform {

  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
    tls = {
      source = "hashicorp/tls"
    }
  }
  required_version = ">= 1.0.1"
}

locals {
  vpc_name     = var.cluster_fqdn
  cluster_name = split(".", var.cluster_fqdn)[0]

  aws_default_tags = merge(
    var.aws_tags_group_level,
    var.aws_tags_cluster_level,
  )
}

provider "aws" {

  default_tags {
    tags = local.aws_default_tags
  }
  region = var.aws_default_region
  assume_role {
    role_arn = var.aws_assume_role
  }
}