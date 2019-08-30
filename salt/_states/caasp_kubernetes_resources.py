from __future__ import absolute_import


def reconcile(name, namespace='kube-system', desired_resources=[]):
    ret = {'name': name,
           'changes': {},
           'comment': ''}

    success, resources = __salt__['caasp_kubernetes_resources.reconcile_desired_resources'](name, namespace, desired_resources)
    ret['changes'] = resources
    ret['result'] = success

    if success:
        ret['comment'] = '%s custom resources correctly applied' % name
    else:
        ret['comment'] = 'Failed to apply %s custom resources' % name

    return ret
