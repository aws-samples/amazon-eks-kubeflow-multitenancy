# locals {
#   resource_list = yamldecode(file("./cwagent-${var.env}-fluentd-setup.yaml")).items
# }
# resource "kubectl_manifest" "cloudwatch-setup" {
#     count = length(local.resource_list)
#     yaml_body = yamlencode(local.resource_list[count.index]) 

# depends_on = [module.my-cluster] 
# }

data "template_file" "fluentd" {
  template = file("./Cloudwatch/cwagent-${var.env}-fluentd-setup.yaml")
  
  vars = {
    region                  = var.region
    eks_name                = var.eks_name
    env                     = var.env
  }
}

resource "local_file" "cloudwatch_rendered_file" {
    content     = data.template_file.fluentd.rendered
    filename = "${path.cwd}/Cloudwatch/cwagent-${var.env}-fluentd-setup-rendered.yaml"
}


resource "null_resource" "kubeflow-Cloudwatch" {
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
apply -f ./Cloudwatch/cwagent-dev-fluentd-setup-rendered.yaml
EOH
  }
}