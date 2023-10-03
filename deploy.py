import yaml
import argparse
from kubernetes import client, config

# Specify a custom kubeconfig file
custom_kubeconfig_path = '~/.kube/config'

def apply_template(file_path):
    with open(file_path) as f:
        manifest = yaml.safe_load_all(f)
        for resource in manifest:
            api_version = resource.get('apiVersion')
            kind = resource.get('kind')
            name = resource['metadata']['name']

            # Load the custom kubeconfig
            config.load_kube_config(config_file=custom_kubeconfig_path)
            namespace = resource['metadata'].get('namespace', 'default')  # Set default namespace if not specified

            if kind == 'Deployment':
                api_instance = client.AppsV1Api()
                try:
                    existing_resource = api_instance.read_namespaced_deployment(name, namespace)
                    api_instance.replace_namespaced_deployment(name, namespace, resource)
                    print(f'{api_version}/{kind} {name} updated successfully')
                except client.exceptions.ApiException as e:
                    if e.status == 404:
                        api_instance.create_namespaced_deployment(namespace, resource)
                        print(f'{api_version}/{kind} {name} created successfully')
                    else:
                        raise e
            elif kind == 'Job':
                api_instance = client.BatchV1Api()
                try:
                    existing_resource = api_instance.read_namespaced_job(name, namespace)
                    api_instance.replace_namespaced_job(name, namespace, resource)
                    print(f'{api_version}/{kind} {name} updated successfully')
                except client.exceptions.ApiException as e:
                    if e.status == 404:
                        api_instance.create_namespaced_job(namespace, resource)
                        print(f'{api_version}/{kind} {name} created successfully')
                    else:
                        raise e
            elif kind == 'Service':
                api_instance = client.CoreV1Api()
                try:
                    existing_resource = api_instance.read_namespaced_service(name, namespace)
                    api_instance.replace_namespaced_service(name, namespace, resource)
                    print(f'{api_version}/{kind} {name} updated successfully')
                except client.exceptions.ApiException as e:
                    if e.status == 404:
                        api_instance.create_namespaced_service(namespace, resource)
                        print(f'{api_version}/{kind} {name} created successfully')
                    else:
                        raise e
            elif kind == 'PersistentVolumeClaim':
                api_instance = client.CoreV1Api()
                try:
                    existing_resource = api_instance.read_namespaced_persistent_volume_claim(name, namespace)
                    api_instance.replace_namespaced_persistent_volume_claim(name, namespace, resource)
                    print(f'{api_version}/{kind} {name} updated successfully')
                except client.exceptions.ApiException as e:
                    if e.status == 404:
                        api_instance.create_namespaced_persistent_volume_claim(namespace, resource)
                        print(f'{api_version}/{kind} {name} created successfully')
                    else:
                        raise e
            elif kind == 'PersistentVolume':
                api_instance = client.CoreV1Api()
                try:
                    existing_resource = api_instance.read_persistent_volume(name)
                    api_instance.replace_persistent_volume(name, resource)
                    print(f'{api_version}/{kind} {name} updated successfully')
                except client.exceptions.ApiException as e:
                    if e.status == 404:
                        api_instance.create_persistent_volume(resource)
                        print(f'{api_version}/{kind} {name} created successfully')
                    else:
                        raise e
            else:
                print(f'Unknown resource type: {kind}')


# Create an argument parser
parser = argparse.ArgumentParser(description='Deploy Kubernetes resources.')

# Add an argument for the file path
parser.add_argument('file_path', help='Path to the YAML file for deployment.')

# Parse the command-line arguments
args = parser.parse_args()

# Load the custom kubeconfig
config.load_kube_config(config_file=custom_kubeconfig_path)

# Apply the template using the provided file path
apply_template(args.file_path)

