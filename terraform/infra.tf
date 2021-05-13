
data "aws_eks_cluster" "management" {
  provider = aws.region1
  name     = module.management_cluster.cluster_id
}

data "aws_eks_cluster_auth" "management" {
  provider = aws.region1
  name     = module.management_cluster.cluster_id
}


data "aws_eks_cluster" "first" {
  provider = aws.region1
  name     = module.first_cluster.cluster_id
}

data "aws_eks_cluster_auth" "first" {
  provider = aws.region1
  name     = module.first_cluster.cluster_id
}

data "aws_eks_cluster" "second" {
  provider = aws.region2
  name     = module.second_cluster.cluster_id
}

data "aws_eks_cluster_auth" "second" {
  provider = aws.region2
  name     = module.second_cluster.cluster_id
}

data "aws_availability_zones" "available_region1" {
  provider = aws.region1
}

data "aws_availability_zones" "available_region2" {
  provider = aws.region2
}


locals {
  management_cluster_name = "${var.stack_name}-management_cluster"
  first_cluster_name      = "${var.stack_name}-first_cluster"
  second_cluster_name     = "${var.stack_name}-second_cluster"
}

############################################ VPCs ############################################


module "vpc_region1" {
  source = "terraform-aws-modules/vpc/aws"
  providers = {
    aws = aws.region1
  }

  version              = "2.78.0"
  name                 = "${var.stack_name}-vpc"
  cidr                 = "172.16.0.0/16"
  azs                  = data.aws_availability_zones.available_region1.names
  private_subnets      = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  public_subnets       = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.management_cluster_name}" = "shared"
    "kubernetes.io/cluster/${local.first_cluster_name}"      = "shared"
    "kubernetes.io/cluster/${local.second_cluster_name}"     = "shared"

    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.management_cluster_name}" = "shared"
    "kubernetes.io/cluster/${local.first_cluster_name}"      = "shared"
    "kubernetes.io/cluster/${local.second_cluster_name}"     = "shared"

    "kubernetes.io/role/internal-elb" = "1"
  }


  tags = {
    stack_name = "${var.stack_name}"
  }
}

module "vpc_region2" {
  source = "terraform-aws-modules/vpc/aws"
  providers = {
    aws = aws.region2
  }

  version              = "2.78.0"
  name                 = "${var.stack_name}-vpc"
  cidr                 = "172.16.0.0/16"
  azs                  = data.aws_availability_zones.available_region2.names
  private_subnets      = ["172.16.1.0/24", "172.16.2.0/24", "172.16.3.0/24"]
  public_subnets       = ["172.16.4.0/24", "172.16.5.0/24", "172.16.6.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  public_subnet_tags = {
    "kubernetes.io/cluster/${local.management_cluster_name}" = "shared"
    "kubernetes.io/cluster/${local.first_cluster_name}"      = "shared"
    "kubernetes.io/cluster/${local.second_cluster_name}"     = "shared"

    "kubernetes.io/role/elb" = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.management_cluster_name}" = "shared"
    "kubernetes.io/cluster/${local.first_cluster_name}"      = "shared"
    "kubernetes.io/cluster/${local.second_cluster_name}"     = "shared"

    "kubernetes.io/role/internal-elb" = "1"
  }

  tags = {
    stack_name = "${var.stack_name}"
  }

}


############################################ EKS cluster ############################################


module "management_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "12.2.0"
  providers = {
    kubernetes = kubernetes.management_cluster
    aws        = aws.region1
  }


  cluster_name    = local.management_cluster_name
  cluster_version = "1.19"
  subnets         = module.vpc_region1.private_subnets

  vpc_id = module.vpc_region1.vpc_id

  node_groups = {
    management = {
      desired_capacity = 2
      max_capacity     = 10
      min_capacity     = 2

      instance_type = "m5.large"
    }
  }

  write_kubeconfig   = true
  config_output_path = "./"

  tags = {
    stack_name = "${var.stack_name}"
  }
}



module "first_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "12.2.0"
  providers = {
    kubernetes = kubernetes.first_cluster
    aws        = aws.region1
  }

  cluster_name    = local.first_cluster_name
  cluster_version = "1.19"
  subnets         = module.vpc_region1.private_subnets

  vpc_id = module.vpc_region1.vpc_id

  node_groups = {
    first = {
      desired_capacity = 2
      max_capacity     = 10
      min_capacity     = 2

      instance_type = "m5.large"
    }
  }

  write_kubeconfig   = true
  config_output_path = "./"
  tags = {
    stack_name = "${var.stack_name}"
  }
}


module "second_cluster" {
  source  = "terraform-aws-modules/eks/aws"
  version = "12.2.0"

  providers = {
    kubernetes = kubernetes.second_cluster
    aws        = aws.region2
  }


  cluster_name    = local.second_cluster_name
  cluster_version = "1.19"
  subnets         = module.vpc_region2.private_subnets

  vpc_id = module.vpc_region2.vpc_id

  node_groups = {
    second = {
      desired_capacity = 2
      max_capacity     = 10
      min_capacity     = 2

      instance_type = "m5.large"
    }
  }

  write_kubeconfig   = true
  config_output_path = "./"
  tags = {
    stack_name = "${var.stack_name}"
  }
}
