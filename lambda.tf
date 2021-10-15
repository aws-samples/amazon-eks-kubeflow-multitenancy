resource "aws_iam_policy" "lambda_kf_manager_policy" {
  name        = "${var.iam_poliy_prefix}_lambda_kf_profile_manager"
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
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents",
            "sts:GetCallerIdentity",
            "eks:DescribeCluster",
            "ec2:DescribeNetworkInterfaces",
            "ec2:CreateNetworkInterface",
            "ec2:DeleteNetworkInterface",
            "ec2:DescribeInstances",
            "ec2:AttachNetworkInterface",
            "iam:PassRole",
            "iam:GetRole",
            "iam:listAttachedRolePolicies",
            "iam:CreateServiceLinkedRole",
            "sts:AssumeRole",
            "ssm:GetParameter",
            "cloudwatch:PutMetricData"
        ],
        "Resource": "*"
      }
     ]
  })
}

resource "aws_iam_role" "lambda_kf_manager_role" {
    name = "${var.iam_role_prefix}_lambda_kf_manager_role"
  
    assume_role_policy = jsonencode({
      Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }]
      Version = "2012-10-17"
    })
}

data "aws_iam_policy" "aws_xray_write_only_access" {
  arn = "arn:aws:iam::aws:policy/AWSXrayWriteOnlyAccess"
}

resource "aws_iam_role_policy_attachment" "Lambda_kf_profile_manager_policy_attachment" {
  depends_on  = [aws_iam_policy.lambda_kf_manager_policy]
  policy_arn  = aws_iam_policy.lambda_kf_manager_policy.arn
  role        = aws_iam_role.lambda_kf_manager_role.name
}


resource "aws_iam_role_policy_attachment" "aws_xray_write_only_access" {
  depends_on  = [aws_iam_policy.lambda_kf_manager_policy]
  role        = aws_iam_role.lambda_kf_manager_role.name
  policy_arn  = "${data.aws_iam_policy.aws_xray_write_only_access.arn}"
}


resource "aws_lambda_function" "kf_profile_manager" {
  depends_on        = [aws_iam_role.lambda_kf_manager_role]
  filename          = "./lambdas/kf_profile_manager.zip"
  function_name     = "${var.eks_name}_lambda_kf_profile"
  role              = aws_iam_role.lambda_kf_manager_role.arn
  handler           = "index.lambda_handler"
  source_code_hash  = filebase64sha256("./lambdas/kf_profile_manager.zip")
  runtime           = "python3.8"
  memory_size       = 512
  timeout           = 60
  publish           = true
  environment {
    variables = {
      clusterName = var.eks_name
      cognitoGroupField = "custom:groups"
    }
  }
  #xray tracking
  tracing_config {
    mode = "Active"
  }
  tags = var.tags
  # vpc_config {
  #   # Every subnet should be able to reach an EFS mount target in the same Availability Zone. Cross-AZ mounts are not permitted.
  #   subnet_ids         = var.subnets
  #   security_group_ids = [module.my-cluster.worker_security_group_id,module.my-cluster.cluster_security_group_id]
  # }
}

#In case we need concurrency
resource "aws_lambda_provisioned_concurrency_config" "kf_profile_manager" {
  count                             = var.lambda_concurreny_enabled ? 1 : 0
  depends_on                        = [aws_lambda_function.kf_profile_manager]
  function_name                     = aws_lambda_function.kf_profile_manager.function_name
  provisioned_concurrent_executions = var.lambda_profile_concurrency
  qualifier                         = aws_lambda_function.kf_profile_manager.version
}

#workaround for the terraform deleting aws-auth
#resource "null_resource" "kubeflow-admin-profile" {
#  triggers = {
#    endpoint = data.aws_eks_cluster.cluster.endpoint
#    ca_crt   = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
#    token    = data.aws_eks_cluster_auth.cluster.token
#  }
#  provisioner "local-exec" {
#    command = <<EOH
#cat >/tmp/ca.crt <<EOF
#${base64decode(data.aws_eks_cluster.cluster.certificate_authority[0].data)}
#EOF
#kubectl \
#--server="${data.aws_eks_cluster.cluster.endpoint}" \
#--certificate-authority=/tmp/ca.crt \
#--token="${data.aws_eks_cluster_auth.cluster.token}" \
#apply -f ./add-kubeflow-admin.yaml
#EOH
#  }
#}