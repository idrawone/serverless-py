from kubernetes import client, config

# Specify a custom kubeconfig file
custom_kubeconfig_path = '~/.kube/config'

def create_config_map_from_script(script_path):
    with open(script_path, 'r') as file:
        script_content = file.read()

    config.load_kube_config(config_file=custom_kubeconfig_path)
    v1 = client.CoreV1Api()

    try:
        v1.read_namespaced_config_map(name='miniobucket', namespace='default')
        print("ConfigMap 'miniobucket' already exists.")
    except client.exceptions.ApiException as e:
        if e.status == 404:
            body = {
                'apiVersion': 'v1',
                'data': {
                    'addbucket.sh': script_content
                },
                'kind': 'ConfigMap',
                'metadata': {
                    'name': 'miniobucket'
                }
            }
            v1.create_namespaced_config_map(namespace='default', body=body)
            print("ConfigMap 'miniobucket' created successfully.")
        else:
            raise e

# Create ConfigMap from script
create_config_map_from_script('./minio/scripts/addbucket.sh')

