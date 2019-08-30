from __future__ import absolute_import


def present(name, secret_key, secret_contents, secret_name_prefix=None, namespace="kube-system"):
    ret = {'name': name,
           'namespace': namespace,
           'changes': {},
           'result': False,
           'comment': ''}

    if __salt__['caasp_kubernetes_secrets.present_with_contents'](secret_key, secret_contents, secret_name_prefix=secret_name_prefix, secret_name=name, namespace=namespace):
        ret['result'] = True
        ret['comment'] = 'Secret is present'
    else:
        ret['comment'] = 'Failed to apply %s secret' % name

    return ret
