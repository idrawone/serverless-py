import argparse
import os
from kubernetes import client, config

# Specify a custom kubeconfig file
custom_kubeconfig_path = '~/.kube/config'

def add_files_to_config_map(script_path, config_map_name):
    with open(script_path, 'r') as file:
        script_content = file.read()

    config.load_kube_config(config_file=custom_kubeconfig_path)
    v1 = client.CoreV1Api()

    try:
        config_map = v1.read_namespaced_config_map(name=config_map_name, namespace='default')
        data = config_map.data or {}
        data[os.path.basename(script_path)] = script_content

        body = {
            'apiVersion': 'v1',
            'data': data,
            'kind': 'ConfigMap',
            'metadata': {
                'name': config_map_name
            }
        }

        v1.replace_namespaced_config_map(name=config_map_name, namespace='default', body=body)
        print(f"File '{os.path.basename(script_path)}' added to ConfigMap '{config_map_name}'.")
    except client.exceptions.ApiException as e:
        if e.status == 404:
            body = {
                'apiVersion': 'v1',
                'data': {
                    os.path.basename(script_path): script_content
                },
                'kind': 'ConfigMap',
                'metadata': {
                    'name': config_map_name
                }
            }
            v1.create_namespaced_config_map(namespace='default', body=body)
            print(f"ConfigMap '{config_map_name}' created with file '{os.path.basename(script_path)}'.")
        else:
            raise e

# Create an argument parser
parser = argparse.ArgumentParser(description='Add files to an existing or new ConfigMap.')

# Add arguments for the folder path and ConfigMap name
parser.add_argument('folder_path', help='Path to the folder containing scripts.')
parser.add_argument('config_map_name', help='Name of the ConfigMap.')

# Parse the command-line arguments
args = parser.parse_args()

# List all files in the folder
files = [f for f in os.listdir(args.folder_path) if os.path.isfile(os.path.join(args.folder_path, f))]

# Load the custom kubeconfig
config.load_kube_config(config_file=custom_kubeconfig_path)

# Add each file to the ConfigMap
for file_name in files:
    script_path = os.path.join(args.folder_path, file_name)
    add_files_to_config_map(script_path, args.config_map_name)

