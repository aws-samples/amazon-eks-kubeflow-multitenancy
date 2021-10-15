data "template_file" "kubeflow" {
  template = file("./kfctl_aws_cognito.v1.2.0.yaml")
  #template = file("./kfctl_aws.v1.2.0.yaml")
  #template = file("${path.module}/../my-configmap.yaml")

  vars = {
    certArn                 = aws_acm_certificate.cert.arn
    cognitoAppClientId      = aws_cognito_user_pool_client.client.id
    cognitoUserPoolArn      = aws_cognito_user_pool.pool.arn
    cognitoUserPoolDomain   = aws_cognito_user_pool_domain.main.domain
    region                  = var.region
    clusterName             = var.eks_name
    clusterArn              = module.my-cluster.cluster_arn 
    namespace               = "kubeflow"
    workerRole              = aws_iam_role.nodegroup.name
  }
}

resource "local_file" "kfctl_yaml" {
    content     = data.template_file.kubeflow.rendered
    filename = "${path.cwd}/kfctl_aws_rendered.yaml"
}

resource "null_resource" "config_kfctl" {
  depends_on = [ local_file.kfctl_yaml , aws_cognito_user_pool_domain.main , module.my-cluster]
    triggers = {
    endpoint = data.aws_eks_cluster.cluster.endpoint
    ca_crt   = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token    = data.aws_eks_cluster_auth.cluster.token
  }
  provisioner "local-exec" {
    command = <<EOH
aws eks --region ${var.region} update-kubeconfig --name ${var.eks_name}
sleep 30
export AWS_CLUSTER_NAME=${var.eks_name}
export KF_NAME=${var.eks_name}
export BASE_DIR=${path.cwd}
export KF_DIR=${path.cwd}/${var.eks_name}
export CONFIG_FILE=${path.cwd}/${var.eks_name}/kfctl_aws_rendered.yaml
cp ${path.cwd}/kfctl_aws_rendered.yaml ${path.cwd}/${var.eks_name}/
mkdir -p ${path.cwd}/${var.eks_name}
cd ${path.cwd}/${var.eks_name}
kfctl apply -V -f ${path.cwd}/${var.eks_name}/kfctl_aws_rendered.yaml
EOH
  }
}