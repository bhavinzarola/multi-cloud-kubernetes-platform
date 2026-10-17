terraform {
  required_version = ">= 1.7"

  backend "s3" {
    bucket = "eks-platform-gitops-tfstate" # override with -backend-config="bucket=<your-bucket>" in CI
    key            = "prod/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "eks-platform-gitops-tf-locks"
    encrypt        = true
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.60"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.30"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.15"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
