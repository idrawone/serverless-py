import yaml
import argparse
from kubernetes import client, config

# Specify a custom kubeconfig file
custom_kubeconfig_path = '~/.kube/config'

def apply_config_map_from_yaml(file_path):
    with open(file_path, 'r') as f:
        manifest = yaml.safe_load_all(f)
        config_map = None
        for resource in manifest:
            if resource.get('kind') == 'ConfigMap':
                config_map = resource
                break

        if config_map is not None:
            config.load_kube_config(config_file=custom_kubeconfig_path)
            v1 = client.CoreV1Api()

            name = config_map['metadata']['name']
            namespace = config_map['metadata'].get('namespace', 'default')

            try:
                v1.read_namespaced_config_map(name=name, namespace=namespace)
                print(f"ConfigMap '{name}' already exists.")
            except client.exceptions.ApiException as e:
                if e.status == 404:
                    v1.create_namespaced_config_map(namespace=namespace, body=config_map)
                    print(f"ConfigMap '{name}' created successfully.")
                else:
                    raise e
        else:
            print("No ConfigMap found in the YAML file.")


# Create an argument parser
parser = argparse.ArgumentParser(description='Deploy Kubernetes resources.')

# Add an argument for the file path
parser.add_argument('file_path', help='Path to the YAML file for deployment.')

# Parse the command-line arguments
args = parser.parse_args()

# Load the custom kubeconfig
config.load_kube_config(config_file=custom_kubeconfig_path)

# Apply the template using the provided file path
apply_config_map_from_yaml(args.file_path)

