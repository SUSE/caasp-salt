from __future__ import absolute_import


def managed(name,
            **kwargs):
    '''
    Generate a /etc/hosts file

    name
        The hosts file to load/generate

    admin_nodes
        The list of admin nodes (as a map of id and IP address).

    master_nodes
        The list of master nodes (as a map of id and IP address).

    worker_nodes
        The list of worker nodes (as a map of id and IP address).

    other_nodes
        The list of other nodes (as a map of id and IP address).

    append
        A map of additional IPs and names.

    marker_start
        Mark for the begining of blocks that will be ignored.

    marker_end
        Mark for the end of blocks that will be ignored.

    .. code-block:: yaml

    /etc/hosts:
      caasp_hosts.managed:
        - append:
            127.0.0.1: localhost
    '''

    ret = {'name': name, 'changes': {}}
    try:
        diff = __salt__['caasp_hosts.managed'](name, **kwargs)
        ret['result'] = True
        if diff:
            ret['changes']['diff'] = '\n'.join(diff)
        else:
            ret['changes'] = False
        ret['comment'] = '{name} successfully generated'.format(**locals())
    except Exception as e:
        ret['result'] = False
        ret['changes'] = {}
        ret['comment'] = '{name} was not generated successfully: {e}'.format(
            **locals())

    return ret
