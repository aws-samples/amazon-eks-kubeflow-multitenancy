#Set the proxy for future processes, and use as an include file
#cloud-init-per instance proxy_config cat << EOF >> /etc/environment
#no_proxy=172.20.0.0/16,10.100.0.0/16,localhost,127.0.0.1,169.254.169.254,.internal,s3.amazonaws.com,.s3.eu-west-1.amazonaws.com,api.ecr.eu-west-1.amazonaws.com,dkr.ecr.eu-west-1.amazonaws.com,ec2.eu-west-1.amazonaws.com,.istio-system.svc,.svc,.svc.cluster.local
#NO_PROXY=172.20.0.0/16,10.100.0.0/16,localhost,127.0.0.1,169.254.169.254,.internal,s3.amazonaws.com,.s3.eu-west-1.amazonaws.com,api.ecr.eu-west-1.amazonaws.com,dkr.ecr.eu-west-1.amazonaws.com,ec2.eu-west-1.amazonaws.com,.istio-system.svc,.svc,.svc.cluster.local
#EOF

set -o xtrace
/etc/eks/bootstrap.sh --apiserver-endpoint '${data.aws_eks_cluster.cluster.endpoint}' --b64-cluster-ca '${module.my-cluster.certificate_authority.0.data}' '${var.eks_name}'

mkdir -p /home/ec2-user/.ssh
chmod 700 /home/ec2-user/.ssh
touch /home/ec2-user/.ssh/authorized_keys
chmod 600 /home/ec2-user/.ssh/authorized_keys
echo "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCjJ2JVys968VP7gnffcYX86OW2B0Qdprf0D1lAbk2Hme5mDbvuyC95A/3GN/dsh/KXq5AHCsGvlSle823SXNzC1Yn5MeyNc9ewB8P0Zd7gKrl4w8SnpfNQwTVdQFhewaffVoAj4gk8pskrU83NyNULCd32cl3eH712mRgvX5Tu08K6+mhLFBMquRJC58SbSpwXW8YAoV5twE+dUup9rZWoShp8TAPYJ1ag6vmCfB0P6FS+LMZ+nNac3THgVBvfBJXJpcBM905IZmh4Arcdu93IxHJ9AyZCJKT/5aHFKZtI/uz6Ls35QOYEZdCbFqa2ZsdeIg2HIrWzKet5qBRnaPUV jose" >> /home/ec2-user/.ssh/authorized_keys
chown -R ec2-user:ec2-user /home/ec2-user/.ssh

set -a
source /etc/environment