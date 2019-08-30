from __future__ import absolute_import

from salt.serializers.yaml import serialize, deserialize


def __virtual__():
    return "caasp_kubernetes_resources"


def kubectl(command, **kwargs):
    return __salt__['caasp_kubernetes_kubectl.kubectl'](command, **kwargs)


def custom_resource_present(custom_resource, namespace='kube-system'):
    ret, _, _ = kubectl('apply -f -', stdin=serialize(custom_resource, default_flow_style=False), namespace=namespace)
    return ret == 0


def custom_resource_missing(custom_resource, namespace='kube-system'):
    ret, _, _ = kubectl('delete -f -', stdin=serialize(custom_resource, default_flow_style=False), namespace=namespace)
    return ret == 0


def fetch_current_custom_resources(custom_resource_name, namespace='kube-system'):
    _, current_resources, _ = kubectl('get %s' % custom_resource_name, namespace=namespace, output='yaml')
    return deserialize(current_resources)


def reconcile_desired_resources(custom_resource_name, namespace, desired_resources=[]):
    current_resources = fetch_current_custom_resources(custom_resource_name, namespace)['items']

    ret = {
        'succeeded': {
            'applied': [],
            'deleted': []
        },
        'errored': {
            'applied': [],
            'deleted': []
        }
    }

    if desired_resources is None:
        desired_resources = []

    desired_resources_names = list('%s' % resource['metadata']['name'] for resource in desired_resources)
    for current_resource in current_resources:
        if current_resource['metadata']['name'] not in desired_resources_names:
            if custom_resource_missing(current_resource):
                ret['succeeded']['deleted'].append(current_resource)
            else:
                ret['errored']['deleted'].append(current_resource)

    for desired_resource in desired_resources:
        if custom_resource_present(desired_resource):
            ret['succeeded']['applied'].append(desired_resource)
        else:
            ret['errored']['applied'].append(desired_resource)

    success = not ret['errored']['applied'] and not ret['errored']['deleted']

    return success, ret
