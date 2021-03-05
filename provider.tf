terraform {
  required_version = ">= 0.14.0"

  required_providers {
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.7.0"
    }
   
  }

  backend "s3" {
    bucket         = "terraform-state-bucket-us-east-1"
    key            = "dev/terraform.tfstate"
    dynamodb_table = "kubeflow-env-state-terraform"
    encrypt        = true
    external_id    = "12345"
  }
}

provider "aws" {
    region                   = var.region
    ignore_tags {
      key_prefixes = ["kubernetes.io/"]
    }
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

