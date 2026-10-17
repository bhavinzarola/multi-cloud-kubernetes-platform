provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = "eks-platform-gitops"
      Environment = "dev"
      Owner       = var.owner
      ManagedBy   = "terraform"
    }
  }
}

locals {
  tags = {
    Project     = "eks-platform-gitops"
    Environment = "dev"
    Owner       = var.owner
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source              = "../../modules/vpc"
  name                = "${var.cluster_name}-vpc"
  cidr_block          = var.vpc_cidr
  azs                 = var.azs
  cluster_name        = var.cluster_name
  single_nat_gateway  = true # dev: single shared NAT Gateway to save cost
  tags                = local.tags
}

module "eks" {
  source                       = "../../modules/eks"
  cluster_name                 = var.cluster_name
  cluster_version              = "1.30"
  vpc_id                       = module.vpc.vpc_id
  private_subnet_ids           = module.vpc.private_subnet_ids
  public_subnet_ids            = module.vpc.public_subnet_ids
  endpoint_public_access       = true # dev: public endpoint for ease of access
  endpoint_public_access_cidrs = ["0.0.0.0/0"]
  system_node_instance_types   = ["t3.medium"]
  system_node_min_size         = 2
  system_node_max_size         = 3
  system_node_desired_size     = 2
  tags                         = local.tags
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
    }
  }
}

provider "kubectl" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  load_config_file       = false

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.aws_region]
  }
}

module "ecr" {
  source          = "../../modules/ecr"
  repository_name = "eks-demo-app"
  max_image_count = 10
  tags            = local.tags
}

module "addons" {
  source                     = "../../modules/addons"
  cluster_name               = module.eks.cluster_name
  vpc_id                     = module.vpc.vpc_id
  lb_controller_role_arn     = module.eks.lb_controller_role_arn
  external_secrets_role_arn  = module.eks.external_secrets_role_arn
  tags                       = local.tags

  depends_on = [module.eks]
}

module "karpenter" {
  source                      = "../../modules/karpenter"
  cluster_name                = module.eks.cluster_name
  cluster_endpoint            = module.eks.cluster_endpoint
  karpenter_role_arn          = module.eks.karpenter_role_arn
  node_instance_profile_name  = "${module.eks.cluster_name}-node-group-role"
  private_subnet_ids          = module.vpc.private_subnet_ids
  cluster_security_group_id   = module.eks.cluster_security_group_id
  tags                        = local.tags

  depends_on = [module.eks]
}
