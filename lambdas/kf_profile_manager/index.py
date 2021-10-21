import json
import boto3
import eks_token
from kubernetes import client, config
from kubernetes.client.exceptions import ApiException
import socket
import os
import logging
import requests
import time
from urllib3.exceptions import InsecureRequestWarning

# Suppress only the single warning from urllib3 needed.
requests.packages.urllib3.disable_warnings(category=InsecureRequestWarning)
logger = logging.getLogger()
logger.setLevel(logging.INFO)


def is_port_open(host, port):
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        return s.connect_ex((host, port)) == 0


# generic variables

# connectivity: get the api_client
cluster_name = os.environ['clusterName']
cognito_group_field = os.environ['cognitoGroupField']
# cluster_name = "kubeflow-ts"
# cognito_group_field = "custom:groups"
cluster_info = boto3.client('eks').describe_cluster(name=cluster_name)['cluster']
ekstoken = eks_token.get_token(cluster_name=cluster_name)['status']['token']
cluster_host = cluster_info['endpoint'][8:]
eks_endpoint = cluster_info['endpoint']

if is_port_open(cluster_host, 443):
    logger.info(f"EKS API Endpoint accessible: https://{cluster_host}:443")
else:
    logger.info(f"EKS API Endpoint NOT accessible: https://{cluster_host}:443")

conf = client.Configuration()
conf.host = cluster_info['endpoint']
conf.verify_ssl = False
conf.api_key = {"authorization": "Bearer " + ekstoken}
api_client = client.ApiClient(conf)


def get_ns():
    core = client.CoreV1Api(api_client)
    try:
        ns_list = []
        for ns in core.list_namespace(timeout_seconds=5).items:
            ns_list.append(ns.metadata.name)
        return ns_list
    except ApiException as e:
        logger.info("Exception when calling CoreV1Api->list_namespace: %s\n" % e)


def apply_rolebinding(user_name: str, user_email: str, group: str):
    custom_objects_api = client.CustomObjectsApi(api_client)
    rolebindings = custom_objects_api.list_namespaced_custom_object(
        group="rbac.authorization.k8s.io",
        version="v1",
        namespace=f"{group}",
        plural="rolebindings",
        pretty="true"
    )
    create_rb = True  # by default create profile

    # iterate over rolebindings to find if new one should be created or old one exists
    for rb in rolebindings['items']:
        rb_metadata_name = rb['metadata']['name']

        if rb_metadata_name == f"user-{user_name}-kubeflow-org-clusterrole-edit":
            logger.info(
                f"rolebinding user-{user_name}-kubeflow-org-clusterrole-edit in namespace={group} already exists")
            create_rb = False
    if create_rb:
        manifest_rolebinding = {
            "apiVersion": "rbac.authorization.k8s.io/v1",
            "kind": "RoleBinding",
            "metadata": {
                "annotations": {
                    "role": "edit",
                    "user": user_email
                },
                "name": f"user-{user_name}-kubeflow-org-clusterrole-edit",
                "namespace": f"{group}"
            },
            "roleRef": {
                "apiGroup": "rbac.authorization.k8s.io",
                "kind": "ClusterRole",
                "name": "kubeflow-edit"
            },
            "subjects": [
                {
                    "apiGroup": "rbac.authorization.k8s.io",
                    "kind": "User",
                    "name": user_email
                }
            ]
        }
        rolebindings = custom_objects_api.create_namespaced_custom_object(
            group="rbac.authorization.k8s.io",
            version="v1",
            namespace=f"{group}",
            plural="rolebindings",
            body=manifest_rolebinding,
            pretty="true"
        )


def remove_rolebinding(user_name: str, namespace: str):
    custom_objects_api = client.CustomObjectsApi(api_client)
    rolebindings = custom_objects_api.list_namespaced_custom_object(
        group="rbac.authorization.k8s.io",
        version="v1",
        namespace=f"{namespace}",
        plural="rolebindings",
        pretty="true"
    )
    # iterate over rolebindings to find if new one should be created or old one exists
    for rb in rolebindings['items']:
        rb_metadata_name = rb['metadata']['name']

        if rb_metadata_name == f"user-{user_name}-kubeflow-org-clusterrole-edit":
            logger.info(
                f"delete_namespaced_custom_object:rolebinding user-{user_name}-kubeflow-org-clusterrole-edit in ns={namespace}")
            try:
                api_response = custom_objects_api.delete_namespaced_custom_object(
                    group="rbac.authorization.k8s.io",
                    version="v1",
                    namespace=f"{namespace}",
                    plural="rolebindings",
                    name=f"user-{user_name}-kubeflow-org-clusterrole-edit",
                    grace_period_seconds="0"
                )
            except ApiException as e:
                logger.info("Exception when calling CustomObjectsApi->delete_namespaced_custom_object: %s\n" % e)


def apply_servicerolebinding(user_name: str, user_email: str, group: str):
    custom_objects_api = client.CustomObjectsApi(api_client)
    servicerolebindings = custom_objects_api.list_namespaced_custom_object(
        group="rbac.istio.io",
        version="v1alpha1",
        namespace=f"{group}",
        plural="servicerolebindings",
        pretty="true"
    )
    create_srb = True  # by default create profile

    # iterate over servicerolebindings to find if new one should be created or old one exists
    for srb in servicerolebindings['items']:
        srb_metadata_name = srb['metadata']['name']

        if srb_metadata_name == f"user-{user_name}-kubeflow-org-clusterrole-edit":
            logger.info(f"servicerolebinding user-{user_name}-kubeflow-org-clusterrole-edit already exists")
            create_srb = False

    if create_srb:
        manifest_servicerolebinding = {
            "apiVersion": "rbac.istio.io/v1alpha1",
            "kind": "ServiceRoleBinding",
            "metadata": {
                "annotations": {
                    "role": "edit",
                    "user": user_email
                },
                "generation": 1,
                "name": f"user-{user_name}-kubeflow-org-clusterrole-edit",
                "namespace": f"{group}"
            },
            "spec": {
                "roleRef": {
                    "kind": "ServiceRole",
                    "name": "ns-access-istio"
                },
                "subjects": [
                    {
                        "properties": {
                            "request.headers[kubeflow-userid]": user_email
                        }
                    }
                ]
            },
            "status": {}
        }
        logger.info(f"create_namespaced_custom_object:manifest_servicerolebinding for user: {user_email}")
        servicerolebindings = custom_objects_api.create_namespaced_custom_object(
            group="rbac.istio.io",
            version="v1alpha1",
            plural="servicerolebindings",
            namespace=f"{group}",
            body=manifest_servicerolebinding,
            pretty="true"
        )
        logger.info(f"created servicerolebindings for user: {user_email}")


def remove_servicerolebinding(user_name: str, namespace: str):
    custom_objects_api = client.CustomObjectsApi(api_client)
    servicerolebindings = custom_objects_api.list_namespaced_custom_object(
        group="rbac.istio.io",
        version="v1alpha1",
        namespace=f"{namespace}",
        plural="servicerolebindings",
        pretty="true"
    )

    # iterate over servicerolebindings to find if new one should be created or old one exists
    for srb in servicerolebindings['items']:
        srb_metadata_name = srb['metadata']['name']

        if srb_metadata_name == f"user-{user_name}-kubeflow-org-clusterrole-edit":
            logger.info(
                f"delete_namespaced_custom_object: servicerolebinding user-{user_name}-kubeflow-org-clusterrole-edit in namespace={namespace}")
            try:
                api_response = custom_objects_api.delete_namespaced_custom_object(
                    group="rbac.istio.io",
                    version="v1alpha1",
                    plural="servicerolebindings",
                    namespace=f"{namespace}",
                    name=f"user-{user_name}-kubeflow-org-clusterrole-edit",
                    grace_period_seconds="0"
                )
            except ApiException as e:
                logger.info("Exception when calling CustomObjectsApi->delete_namespaced_custom_object: %s\n" % e)


def profile_exists(name, api):
    custom_objects = api.list_cluster_custom_object(
        group="kubeflow.org",
        version="v1",
        plural="profiles",
        pretty="true"
    )
    for item in custom_objects['items']:
        if item['spec']['owner']['name'] == name:
            logger.info(f"FOUND profile name={name}")
            return True
    logger.info(f"Profile name={name} not yet found")
    return False


def create_profile(username, email, api):
    profile_manifest = {
        "apiVersion": "kubeflow.org/v1",
        "kind": "Profile",
        "metadata": {
            "name": f"profile-{username}"
        },
        "spec": {
            "owner": {
                "kind": "User",
                "name": email  # name -> email
            },
            "resourceQuotaSpec": {
                "hard": {
                    "cpu": "0",
                    "memory": "0Gi",
                    "nvidia.com/gpu": "0",
                    "persistentvolumeclaims": "0",
                    "requests.storage": "0Gi"
                }
            }
        }
    }
    logger.info(f"profile: profile-{username} created")
    api.create_cluster_custom_object(
        group="kubeflow.org",
        version="v1",
        plural="profiles",
        body=profile_manifest,
        pretty="true"
    )


def create_profile_ns(email, namespace, api):
    profile_manifest = {
        "apiVersion": "kubeflow.org/v1",
        "kind": "Profile",
        "metadata": {
            "name": f"{namespace}"
        },
        "spec": {
            "owner": {
                "kind": "User",
                "name": email  # name -> email
            }
        }
    }
    logger.info(f"profile manifest for user:{email} in Namespace:{namespace}")
    api.create_cluster_custom_object(
        group="kubeflow.org",
        version="v1",
        plural="profiles",
        body=profile_manifest,
        pretty="true"
    )


def lambda_handler(event, context):
    logger.info("event = " + json.dumps(event))

    groups = event['request']['userAttributes'][cognito_group_field]
    data_groups = event['request']['userAttributes'][cognito_group_field]
    groups = data_groups.replace("[", "").replace("]", "").split(", ")
    groups = [element.lower() for element in groups];
    logger.info("groups = " + json.dumps(groups))
    name = event['userName'].split("\\")
    if len(name) == 1:
        user_name = name[0]
    else:
        user_name = name[1]
    user_email = event['request']['userAttributes']['email']

    namespaces = get_ns()

    # create the users profile due to restriction in kubeflow
    api = client.CustomObjectsApi(api_client)
    if not profile_exists(user_email, api):
        logger.info(f"creating profile: {user_email}")
        create_profile(user_name, user_email, api)

    while not profile_exists(user_email, api):
        time.sleep(2)

    # create the missing namespaces with admin owner
    for group in groups:
        if not group in namespaces:
            logger.info("creating profile:")
            create_profile_ns("admin@kubeflow.com", group, api)
        else:
            logger.info("Profile: " + group + " already exists")
    # refresh namespaces
    namespaces = get_ns()
    for namespace in namespaces:
        logger.info(f"Namespace: {namespace}")
        group = namespace
        if group in groups:
            logger.info(
                f"ENSURE rolebinding for user={user_name} nsgroup={group} user_email={user_email} namespace={namespace}")
            apply_rolebinding(user_name=user_name, user_email=user_email, group=group)
            logger.info(
                f"ENSURE servicerolebinding for user={user_name} group={group} user_email={user_email} namespace={namespace}")
            apply_servicerolebinding(user_name=user_name, user_email=user_email, group=group)
        else:
            logger.info(f"REVOKE rolebinding user={user_name} in NAMESPACE={namespace}")
            remove_rolebinding(user_name=user_name, namespace=namespace)
            logger.info(f"REVOKE servicerolebinding user={user_name} in NAMESPACE={namespace}")
            remove_servicerolebinding(user_name=user_name, namespace=namespace)

    return event
