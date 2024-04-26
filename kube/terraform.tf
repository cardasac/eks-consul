terraform {
  backend "s3" {
    bucket = "alviralex-terraform"
    key    = "eks/apps/terraform.tfstate"
    region = "eu-west-1"

    dynamodb_table = "base-terraform"
    encrypt        = true
  }

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">= 2.4.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = ">= 2.3.0"
    }
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.7.0"
    }
  }

  required_version = ">= 1.6"
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
  }
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

data "aws_eks_cluster" "cluster" {
  name = "tud-eks-alex"
}

data "aws_eks_cluster_auth" "cluster" {
  name = "tud-eks-alex"
}

provider "aws" {
  region = var.region
}
