# EKS Configuration

data "aws_eks_cluster" "cluster" {
  name                                  = module.my-cluster.cluster_id
}

data "aws_eks_cluster_auth" "cluster" {
  name                                  = module.my-cluster.cluster_id
}


#lets fix the tags 
resource "aws_ec2_tag" "vpc_tag" {
  resource_id = var.vpc_id
  key         = "kubernetes.io/cluster/${var.eks_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "Subets_cluster_Tags" {
  for_each    = toset(var.subnets)
  resource_id = each.value
  key         = "kubernetes.io/cluster/${var.eks_name}"
  value       = "shared"
}

resource "aws_ec2_tag" "private_subnet_tag" {
  for_each    = toset(var.priv_subnets)
  resource_id = each.value
  key         = "kubernetes.io/role/internal-elb"
  value       = "1"
}

resource "aws_ec2_tag" "public_subnet_tag" {
  for_each    = toset(var.pub_subnets)
  resource_id = each.value
  key         = "kubernetes.io/role/elb"
  value       = "1"
}

module "my-cluster" {
  source                                = "terraform-aws-modules/eks/aws"
  cluster_name                          = var.eks_name
  cluster_version                       = "1.18"
  subnets                               = var.subnets
  vpc_id                                = var.vpc_id
  manage_aws_auth                       = false
  cluster_create_security_group         = true
  worker_create_security_group          = true
  cluster_endpoint_private_access       = true
  cluster_endpoint_private_access_cidrs = ["172.20.0.0/16", "10.0.0.0/8"]
  cluster_endpoint_public_access        = true
  manage_cluster_iam_resources          = true
  cluster_iam_role_name                 = "${var.iam_role_prefix}_kubeflow_Cluster"
  cluster_enabled_log_types             = ["api", "audit", "authenticator", "controllerManager", "scheduler"]
  cluster_encryption_config = [
    {
      provider_key_arn = var.kms_key_arn
      resources        = ["secrets"]
    }
  ]
  workers_group_defaults = {
  	root_volume_type                    = "gp2"
  }
  tags = var.tags
}

#NodeGroup Section
#IAM ROLE for the nodegroups
resource "aws_iam_role" "nodegroup" {
    name = "${var.iam_role_prefix}_kubeflow_Worker"
  
    assume_role_policy = jsonencode({
      Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }]
      Version = "2012-10-17"
    })
}

resource "aws_iam_role_policy_attachment" "nodegroup-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.nodegroup.name
}

resource "aws_iam_role_policy_attachment" "nodegroup-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.nodegroup.name
}

resource "aws_iam_role_policy_attachment" "nodegroup-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.nodegroup.name
}

resource "aws_iam_policy" "alb_ingress_policy" {
  name        = "${var.iam_poliy_prefix}_alb_ingress_policy"
  path        = "/"
  description = "Policy for ALB ingress"

  # Terraform's "jsonencode" function converts a
  # Terraform expression result to valid JSON syntax.
  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "acm:DescribeCertificate",
          "acm:ListCertificates",
          "acm:GetCertificate"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:CreateSecurityGroup",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DeleteSecurityGroup",
          "ec2:DescribeAccountAttributes",
          "ec2:DescribeAddresses",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:DescribeInternetGateways",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSubnets",
          "ec2:DescribeTags",
          "ec2:DescribeVpcs",
          "ec2:ModifyInstanceAttribute",
          "ec2:ModifyNetworkInterfaceAttribute",
          "ec2:RevokeSecurityGroupIngress"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "elasticloadbalancing:AddListenerCertificates",
          "elasticloadbalancing:AddTags",
          "elasticloadbalancing:CreateListener",
          "elasticloadbalancing:CreateLoadBalancer",
          "elasticloadbalancing:CreateRule",
          "elasticloadbalancing:CreateTargetGroup",
          "elasticloadbalancing:DeleteListener",
          "elasticloadbalancing:DeleteLoadBalancer",
          "elasticloadbalancing:DeleteRule",
          "elasticloadbalancing:DeleteTargetGroup",
          "elasticloadbalancing:DeregisterTargets",
          "elasticloadbalancing:DescribeListenerCertificates",
          "elasticloadbalancing:DescribeListeners",
          "elasticloadbalancing:DescribeLoadBalancers",
          "elasticloadbalancing:DescribeLoadBalancerAttributes",
          "elasticloadbalancing:DescribeRules",
          "elasticloadbalancing:DescribeSSLPolicies",
          "elasticloadbalancing:DescribeTags",
          "elasticloadbalancing:DescribeTargetGroups",
          "elasticloadbalancing:DescribeTargetGroupAttributes",
          "elasticloadbalancing:DescribeTargetHealth",
          "elasticloadbalancing:ModifyListener",
          "elasticloadbalancing:ModifyLoadBalancerAttributes",
          "elasticloadbalancing:ModifyRule",
          "elasticloadbalancing:ModifyTargetGroup",
          "elasticloadbalancing:ModifyTargetGroupAttributes",
          "elasticloadbalancing:RegisterTargets",
          "elasticloadbalancing:RemoveListenerCertificates",
          "elasticloadbalancing:RemoveTags",
          "elasticloadbalancing:SetIpAddressType",
          "elasticloadbalancing:SetSecurityGroups",
          "elasticloadbalancing:SetSubnets",
          "elasticloadbalancing:SetWebACL"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "iam:CreateServiceLinkedRole",
          "iam:GetServerCertificate",
          "iam:ListServerCertificates"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "cognito-idp:DescribeUserPoolClient"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "waf-regional:GetWebACLForResource",
          "waf-regional:GetWebACL",
          "waf-regional:AssociateWebACL",
          "waf-regional:DisassociateWebACL"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "tag:GetResources",
          "tag:TagResources"
        ],
        "Resource": "*"
      },
      {
        "Effect": "Allow",
        "Action": [
          "waf:GetWebACL"
        ],
        "Resource": "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "nodegroup-ElasticLoadBalancingFullAccess" {
  depends_on  = [aws_iam_policy.alb_ingress_policy]
  policy_arn  = aws_iam_policy.alb_ingress_policy.arn
  role        = aws_iam_role.nodegroup.name
}

#workaround for the terraform deleting aws-auth
resource "kubernetes_config_map" "iam_nodes_config_map" {
  depends_on = [aws_iam_role.lambda_kf_manager_role, module.my-cluster]
  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = <<ROLES
- rolearn: ${aws_iam_role.nodegroup.arn}
  username: system:node:{{EC2PrivateDNSName}}
  groups:
    - system:bootstrappers
    - system:nodes
ROLES
    mapUsers = <<USERS
      - userarn: ${aws_iam_role.lambda_kf_manager_role.arn}
        username: eksadmin
        groups:
          - system:masters
  USERS
}
}

data "aws_ami" "eks-worker" {
  filter {
    name   = "name"
    values = ["amazon-eks-node-${module.my-cluster.cluster_version}-v*"]
  }

  most_recent = true
  owners      = ["602401143452"] # Amazon EKS AMI Account ID
}

locals {
  main-node-userdata = <<USERDATA
#!/bin/bash
set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${module.my-cluster.cluster_endpoint}' --b64-cluster-ca '${data.aws_eks_cluster.cluster.certificate_authority.0.data}' '${var.eks_name}'
USERDATA
}

resource "aws_launch_template" "launch_template" {
    depends_on = [
      aws_iam_role_policy_attachment.nodegroup-AmazonEKSWorkerNodePolicy,
      aws_iam_role_policy_attachment.nodegroup-AmazonEKS_CNI_Policy,
      aws_iam_role_policy_attachment.nodegroup-AmazonEC2ContainerRegistryReadOnly,
      aws_iam_role_policy_attachment.nodegroup-ElasticLoadBalancingFullAccess
    ]
    name_prefix                 = "${var.eks_name}-nodegroup-LT"
    image_id                    = data.aws_ami.eks-worker.id
    instance_type               = var.cpu_worker_type
    user_data                   = base64encode(local.main-node-userdata)
    key_name                    = var.ssh_key_name
    
    network_interfaces {
      associate_public_ip_address = var.associate_public_ip_address
      security_groups             = [module.my-cluster.worker_security_group_id]
    }
  
    tag_specifications {
      resource_type = "instance"
      tags =  merge(var.tags,
        {
            Name                                    = "${var.eks_name}-nodegroup-LT"
            "kubernetes.io/cluster/${var.eks_name}" = "owned"
        }
      )
    }
    lifecycle {
      create_before_destroy = true
    }
}


resource "aws_eks_node_group" "example" {
  cluster_name      = var.eks_name
    node_group_name = "${var.eks_name}-nodegroup"
    node_role_arn   = aws_iam_role.nodegroup.arn
    subnet_ids      = var.pub_subnets[*]
  
    scaling_config {
      desired_size = var.nodegroup_desired_size
      max_size     = var.nodegroup_max_size
      min_size     = var.nodegroup_min_size
    }
    # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
    # Otherwise, EKS will not be able to properly delete EC2 Instances and Elastic Network Interfaces.
    depends_on = [
      module.my-cluster,
      aws_launch_template.launch_template
    ]
    launch_template {
      name                                    = aws_launch_template.launch_template.name
      version                                 = aws_launch_template.launch_template.latest_version
    }
   tags =  merge(var.tags,
    {
        "kubernetes.io/cluster/${var.eks_name}" = "owned"
    }
  )

}

resource "kubectl_manifest" "proxy" {
  yaml_body = file("${path.module}/proxy-env-vars-config.yaml")
}

resource "null_resource" "k8s_patcher_kube-proxy" {
  depends_on = [ kubectl_manifest.proxy ]
  triggers = {
    endpoint = data.aws_eks_cluster.cluster.endpoint
    ca_crt   = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token    = data.aws_eks_cluster_auth.cluster.token
  }
  provisioner "local-exec" {
    command = <<EOH
cat >/tmp/ca.crt <<EOF
${base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)}
EOF
kubectl \
--server="${data.aws_eks_cluster.cluster.endpoint}" \
--certificate-authority=/tmp/ca.crt \
--token="${data.aws_eks_cluster_auth.cluster.token}" \
patch -n kube-system \
-p '{ "spec": {"template": { "spec": { "containers": [ { "name": "kube-proxy", "envFrom": [ { "configMapRef": {"name": "proxy-environment-variables"} } ] } ] } } } }' \
daemonset kube-proxy
EOH
  }
}

resource "null_resource" "k8s_set_kube-proxy" {
  depends_on = [ null_resource.k8s_patcher_kube-proxy ]
  triggers = {
    endpoint = data.aws_eks_cluster.cluster.endpoint
    ca_crt   = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token    = data.aws_eks_cluster_auth.cluster.token
  }
  provisioner "local-exec" {
    command = <<EOH
cat >/tmp/ca.crt <<EOF
${base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)}
EOF
kubectl \
--server="${data.aws_eks_cluster.cluster.endpoint}" \
--certificate-authority=/tmp/ca.crt \
--token="${data.aws_eks_cluster_auth.cluster.token}" \
set env daemonset/kube-proxy \
--namespace=kube-system \
--from=configmap/proxy-environment-variables \
--containers='*'
EOH
  }
}

#outputs
output "cluster_id" {
  value = module.my-cluster.cluster_id
}

output "cluster_version" {
  value = module.my-cluster.cluster_version
}

output "cluster_endpoint" {
  value = module.my-cluster.cluster_endpoint
}

output "cluster_arn" {
  value = module.my-cluster.cluster_arn
}

output "cluster_oidc_issuer_url" {
  value = module.my-cluster.cluster_oidc_issuer_url
}

output "cluster_primary_security_group_id" {
  value = module.my-cluster.cluster_primary_security_group_id
}

output "cluster_security_group_id" {
  value = module.my-cluster.cluster_security_group_id
}

output "worker_security_group_id" {
  value = module.my-cluster.worker_security_group_id
}
output "worker_iam_role_name" {
  value = module.my-cluster.worker_iam_role_name
}
output "worker_iam_role_arn" {
  value = module.my-cluster.worker_iam_role_arn
}
output "base64data" {
  value = data.aws_eks_cluster.cluster.certificate_authority.0.data
  }
output "IAM_Policy_ALB" {
  value = aws_iam_policy.alb_ingress_policy.arn
}