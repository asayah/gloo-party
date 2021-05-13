provider "aws" {
  region = "us-east-1"
}

provider "aws" {
  region = "us-west-1"
  alias  = "region1"
}

provider "aws" {
  region = "us-east-2"
  alias  = "region2"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.management.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.management.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.management.token
  load_config_file       = false
  version                = "~> 1.11"
  alias                  = "management_cluster"
}


provider "kubernetes" {
  host                   = data.aws_eks_cluster.first.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.first.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.first.token
  load_config_file       = false
  version                = "~> 1.11"
  alias                  = "first_cluster"
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.second.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.second.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.second.token
  load_config_file       = false
  version                = "~> 1.11"
  alias                  = "second_cluster"
}


provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.management.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.management.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.management.token
  }

  alias = "management_cluster"
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.first.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.first.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.first.token
  }

  alias = "first_cluster"
}


provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.second.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.second.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.second.token
  }

  alias = "second_cluster"
}



provider "kubectl" {
  alias                  = "management_cluster"
  host                   = data.aws_eks_cluster.management.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.management.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.management.token


  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws-iam-authenticator"
    args = [
      "token",
      "-i",
      module.management_cluster.cluster_id,
    ]
  }
}

provider "kubectl" {
  alias                  = "first_cluster"
  host                   = data.aws_eks_cluster.first.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.first.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.first.token

  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws-iam-authenticator"
    args = [
      "token",
      "-i",
      module.first_cluster.cluster_id,
    ]
  }
}

provider "kubectl" {
  alias                  = "second_cluster"
  host                   = data.aws_eks_cluster.second.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.second.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.second.token


  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws-iam-authenticator"
    args = [
      "token",
      "-i",
      module.second_cluster.cluster_id,
    ]
  }
}

terraform {
  required_version = ">= 0.14"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
  }
}