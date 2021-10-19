terraform {
  required_version = ">= 0.14.0"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
    aws     = {
      version = ">=1.22.0"
    }
  }

  backend "s3" {
    bucket         = "terraform-kubeflow-state-us-east-1"
    key            = "dev/terraform.tfstate"
    dynamodb_table = "terraformkubeflow"
    encrypt        = true
    external_id    = "12345"
  }
}

provider "aws" {
  region      = var.region
  ignore_tags {
    key_prefixes = ["kubernetes.io/"]
  }
  # Make it faster by skipping something
  skip_get_ec2_platforms      = true
  skip_metadata_api_check     = true
  skip_region_validation      = true
  skip_credentials_validation = true
  skip_requesting_account_id  = true
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
}

