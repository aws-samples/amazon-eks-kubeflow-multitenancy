# AWS account related
variable "account_id" {}
variable "region" {
    default = "us-east-1"
}

# EKS related
variable "eks_name" {}
variable "iam_role_prefix" {}
variable "cpu_worker_type" {}
variable "cognito_domain" {}
variable "auth_base_domain" {}
variable "route53_domain" {}
variable "cert_alt_names" {}
variable "iam_poliy_prefix" {}
variable "associate_public_ip_address" {}
variable "nodegroup_min_size" {}
variable "nodegroup_max_size" {}
variable "nodegroup_desired_size" {}
variable "ssh_key_name" {}
variable "adfs_url" {}
variable "kubeflow_domain" {}
variable "lambda_concurreny_enabled" {}
variable "lambda_profile_concurrency" {}
variable "tags" {}
variable "env" {}