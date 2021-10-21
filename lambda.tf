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
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "ec2:CreateNetworkInterface",
                "ec2:DeleteNetworkInterface",
                "ec2:AttachNetworkInterface"
            ],
            "Resource": [
                "arn:aws:ec2:us-east-1:627906291938:network-interface/*",
                "arn:aws:ec2:us-east-1:627906291938:subnet/*",
                "arn:aws:ec2:us-east-1:627906291938:security-group/*",
                "arn:aws:ec2:us-east-1:627906291938:instance/*"
            ]
        },
        {
            "Sid": "VisualEditor1",
            "Effect": "Allow",
            "Action": [
                "iam:GetRole",
                "iam:PassRole",
                "iam:CreateServiceLinkedRole",
                "iam:ListAttachedRolePolicies",
                "logs:PutLogEvents"
            ],
            "Resource": [
                "arn:aws:logs:us-east-1:627906291938:log-group:*:log-stream:*",
                "arn:aws:iam::627906291938:role/*"
            ]
        },
        {
            "Sid": "VisualEditor2",
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogStream",
                "sts:AssumeRole",
                "eks:DescribeCluster",
                "logs:CreateLogGroup",
                "ssm:GetParameter"
            ],
            "Resource": [
                "arn:aws:logs:us-east-1:627906291938:log-group:*",
                "arn:aws:iam::627906291938:role/*",
                "arn:aws:ssm:us-east-1:627906291938:parameter/*",
                "arn:aws:eks:us-east-1:627906291938:cluster/*"
            ]
        },
        {
            "Sid": "VisualEditor3",
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "cloudwatch:PutMetricData",
                "ec2:DescribeNetworkInterfaces",
                "sts:GetCallerIdentity"
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

resource "null_resource" "my_lambda_buildstep" {
  triggers = {
    handler      = "${base64sha256(file("lambdas/kf_profile_manager/index.py"))}"
    requirements = "${base64sha256(file("lambdas/kf_profile_manager/requirements.txt"))}"
    build        = "${base64sha256(file("lambdas/kf_profile_manager/build.sh"))}"
  }

  provisioner "local-exec" {
    command = "${path.module}/lambdas/kf_profile_manager/build.sh"
  }
}

data "archive_file" "my_lambda_function_with_dependencies" {
  source_dir  = "${path.module}/lambdas/kf_profile_manager/"
  output_path = "${path.module}lambdas/kf_profile_manager.zip"
  type        = "zip"

  depends_on = [null_resource.my_lambda_buildstep]
}

resource "aws_lambda_function" "kf_profile_manager" {
  depends_on        = [aws_iam_role.lambda_kf_manager_role, data.archive_file.my_lambda_function_with_dependencies ]
  #filename          = "./lambdas/kf_profile_manager.zip"
  function_name     = "${var.eks_name}_lambda_kf_profile"
  role              = aws_iam_role.lambda_kf_manager_role.arn
  handler           = "index.lambda_handler"
  #source_code_hash  = filebase64sha256("./lambdas/kf_profile_manager.zip")
  filename         = "${data.archive_file.my_lambda_function_with_dependencies.output_path}"
  source_code_hash = "${data.archive_file.my_lambda_function_with_dependencies.output_base64sha256}"
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

