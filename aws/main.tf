provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  cluster_name = "tud-eks-alex"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = ">= 5.7.0"

  name = "tud-vpc"

  cidr = "10.0.0.0/16"
  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                      = 1
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"             = 1
  }
}

# module "vpc" {
#   source  = "aws-ia/vpc/aws"
#   version = ">= 4.2.0"

#   name                                 = "multi-az-vpc"
#   cidr_block                           = "10.0.0.0/16"
#   vpc_assign_generated_ipv6_cidr_block = true
#   vpc_egress_only_internet_gateway     = true
#   az_count                             = 3

#   subnets = {
#     # Dual-stack subnet
#     public = {
#       name_prefix               = "my_public" # omit to prefix with "public"
#       netmask                   = 24
#       assign_ipv6_cidr          = true
#       nat_gateway_configuration = "single_az" # options: "single_az", "none"
#     }
#     # IPv4 only subnet
#     private = {
#       # omitting name_prefix defaults value to "private"
#       # name_prefix  = "private_with_egress"
#       netmask                 = 24
#       connect_to_public_natgw = true
#     }
#     # IPv6-only subnet
#     private_ipv6 = {
#       ipv6_native      = true
#       assign_ipv6_cidr = true
#       connect_to_eigw  = true
#     }
#   }

#   # vpc_flow_logs = {
#   #   log_destination_type = "cloud-watch-logs"
#   #   retention_in_days    = 180
#   # }
# }

data "aws_eks_cluster" "cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

data "aws_eks_cluster_auth" "cluster" {
  name       = module.eks.cluster_name
  depends_on = [module.eks]
}

module "eks" {
  source                                   = "terraform-aws-modules/eks/aws"
  version                                  = ">= 20.0"
  enable_cluster_creator_admin_permissions = true
  cluster_name                             = local.cluster_name
  cluster_version                          = "1.29"
  cluster_addons = {
    coredns = {
      most_recent              = true
      service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
    }
    kube-proxy = {
      most_recent              = true
      service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
    }
    aws-ebs-csi-driver = {
      most_recent              = true
      service_account_role_arn = module.irsa-ebs-csi.iam_role_arn
    }
  }

  vpc_id                         = module.vpc.vpc_id
  subnet_ids                     = module.vpc.private_subnets
  cluster_endpoint_public_access = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"
  }

  eks_managed_node_groups = {
    consul = {
      name = "consul"

      instance_types = ["t3.medium"]

      min_size     = 1
      max_size     = 5
      desired_size = 3
    }
  }

  node_security_group_additional_rules = {
    ingress_self_all = {
      description = "Node to node all ports/protocols"
      protocol    = "-1"
      from_port   = 0
      to_port     = 0
      type        = "ingress"
      self        = true
    }
    ingress_cluster_all = {
      description                   = "Cluster to node all ports/protocols"
      protocol                      = "-1"
      from_port                     = 0
      to_port                       = 0
      type                          = "ingress"
      source_cluster_security_group = true
    }
    egress_all = {
      description      = "Node all egress"
      protocol         = "-1"
      from_port        = 0
      to_port          = 0
      type             = "egress"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
    }
  }
}

data "aws_iam_policy" "ebs_csi_policy" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}

module "irsa-ebs-csi" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-assumable-role-with-oidc"
  version = ">= 5.37.2"

  create_role                   = true
  role_name                     = "AmazonEKSTFEBSCSIRole-${module.eks.cluster_name}"
  provider_url                  = module.eks.oidc_provider
  role_policy_arns              = [data.aws_iam_policy.ebs_csi_policy.arn]
  oidc_fully_qualified_subjects = ["system:serviceaccount:kube-system:ebs-csi-controller-sa"]
}
