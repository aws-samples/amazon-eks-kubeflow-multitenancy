# Building multi-user isolation in Kubeflow on Amazon EKS using Amazon Cognito and ADFS.


##  Description

he Kubeflow project (https://www.kubeflow.org/) is dedicated to making deployments of machine learning (ML) workflows on Kubernetes simple, portable and scalable. The project’s goal is not to recreate other services, but to provide a straightforward way to deploy best-of-breed open-source systems for ML to diverse infrastructures. In this blogpost, we will explore how to deploy Kubeflow on Amazon Elastic Kubernetes Service (https://aws.amazon.com/eks/) and how to achieve multi-user isolation using Amazon Cognito and ADFS. A lot of our enterprise customers have the necessity to integrate Kubeflow with their existing authentication mechanism and we will walk you through the process of achieving this using Amazon Cognito and ADFS to achieve isolation of notebooks, experiments etc. between various users/user groups. To get an overview of Kubeflow multi-tenancy please refer the documentation here (https://www.kubeflow.org/docs/components/multi-tenancy/).

## Architecture

![Architecture](docs/Kubeflow.png)

The above diagram depicts the following workflow.

1. User opens the custom URL for the Kubeflow ALB
2. Route53 resolves the FQDN to the ALB
3. ALB redirect the request to the kubeflow containers running on EKS
4. IstioGateway intercepts the request
5. IstoGateway redirects the request to cognito
6. Cognito App client is configured with a custom Domain and valid certificate from Amazon Certificate Manager
7. Cognito redirects the request to the configured IDP provider (ADFS in this example)
8. User logs in and ADFS redirects to Cognito with the SAML assertion
9. Cognito has the Pre-Token generation event configured to trigger the Lambda function
10. “Profile Manager” Lambda is triggered with the groups that the user bellongs in the AD as part of the event
11. Lambda, based on the groups received on the event will connect to the Amazon EKS and generate the necessary role and serviceRoleBindings
12. Cognito redirect back to the Kubeflow UI



## Instructions

This Terraform module assumes some resources already exist and it has parameters to fill with those.

Change the Parameters in the file terraform.tfvars and run terraform apply

#### Requirements
* VPC with 2 private subnets
* ADFS
* Route53 Custom Domain
* Existing CMK KMS (not mandatory)


#### Required parameters
* region                      =   <region>
* account_id                  =   <account_id>
* vpc_id                      =   <vpc_id>
* kms_key_arn                 =   <kms_ley>
* subnets                     =   [<subnets>]
* priv_subnets                =   [<priv_subnets>]
* pub_subnets                 =   [<pub_subnets>]
* eks_name                    =   "kubeflow-DEMO"
* iam_role_prefix             =   "kubeflow"
* iam_poliy_prefix            =   "kubeflow"
* cpu_worker_type             =   "m5.large"
* route53_domain              =   "kubeflow-DEMO.<customDomain>"
* cert_alt_names              =   ["auth.kubeflow-DEMO.<customDomain>","cognito.auth.kubeflow- DEMO.<customDomain>","kubeflow.kubeflow-DEMO.<customDomain>"]
* auth_base_domain            =   "auth.kubeflow-DEMO.<customDomain>"
* cognito_domain              =   "cognito.auth.kubeflow-DEMO.<customDomain>"
* kubeflow_domain             =   "kubeflow.kubeflow-DEMO.<customDomain>"
* associate_public_ip_address =   true
* nodegroup_min_size          =   1
* nodegroup_max_size          =   6
* nodegroup_desired_size      =   6
* ssh_key_name                =   <MyKey>
* adfs_url                    =   <ADFS address>
* lambda_concurreny_enabled   =   false
* lambda_profile_concurrency  =   10
* tags                        = {}
* env                         = "<Environment>"  
