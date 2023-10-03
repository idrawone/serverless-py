import argparse
import base64
from kubernetes import client, config

# Specify a custom kubeconfig file
custom_kubeconfig_path = '~/.kube/config'

def create_secret(secret_name, data):
    config.load_kube_config(config_file=custom_kubeconfig_path)
    v1 = client.CoreV1Api()

    try:
        v1.read_namespaced_secret(name=secret_name, namespace='default')
        print(f"Secret '{secret_name}' already exists.")
    except client.exceptions.ApiException as e:
        if e.status == 404:
            body = {
                'apiVersion': 'v1',
                'kind': 'Secret',
                'metadata': {
                    'name': secret_name
                },
                'type': 'generic',
                'data': {key: base64.b64encode(value.encode()).decode() for key, value in data.items()}
            }
            v1.create_namespaced_secret(namespace='default', body=body)
            print(f"Secret '{secret_name}' created successfully.")
        else:
            raise e

# Create an argument parser
parser = argparse.ArgumentParser(description='Create a Kubernetes Secret.')

# Add arguments for the Secret name and data
parser.add_argument('secret_name', help='Name of the Secret.')
parser.add_argument('--data', nargs='+', help='Data for the Secret in key=value format.')

# Parse the command-line arguments
args = parser.parse_args()

# Parse data argument into dictionary
data = {}
if args.data:
    for item in args.data:
        key, value = item.split('=')
        data[key] = value

# Create the Secret
create_secret(args.secret_name, data)

