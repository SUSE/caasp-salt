from __future__ import absolute_import

import logging

log = logging.getLogger(__name__)

# default number of trials for etcdctl
DEFAULT_ATTEMPTS = 10

# ... and the interval between them
DEFAULT_ATTEMPTS_INTERVAL = 2

# default etcd peer port
ETCD_PEER_PORT = 2380

def api_version():
    return __salt__['caasp_etcd.api_version']()

def etcdctl(name, retry={}, **kwargs):
    '''
    Run an etcdctl command

    Arguments:

    In addition to all the arguments supported by the `caasp_cmd.run` state.

    * `skip_this`: (optional) skip current node when calculating the list of etcd endpoints.

    '''
    retry_ = {'attempts': DEFAULT_ATTEMPTS,
              'interval': DEFAULT_ATTEMPTS_INTERVAL,
              'until': None}
    retry_.update(retry)

    skip_this = kwargs.pop('skip_this', False)

    args = __salt__['caasp_etcd.get_etcdctl_args_str'](skip_this=skip_this)
    cmd = 'etcdctl {} {}'.format(args, name)
    if api_version() == 'etcd2':
        cmd = 'ETCDCTL_API=2 {}'.format(cmd)
    else:
        cmd = 'ETCDCTL_API=3 {}'.format(cmd)

    log.debug('CaaS: running etcdctl as: %s', cmd)

    return __states__['caasp_cmd.run'](name=cmd,
                                       retry=retry_,
                                       **kwargs)


def healthy(name, **kwargs):
    log.debug('CaaS: checking etcd health')
    result = {'name': "healthy.{0}".format(name),
              'result': True,
              'comment': "Cluster is healthy",
              'changes': {}}

    if not __salt__['caasp_etcd.healthy'](**kwargs):
        result.update({
            'result': False,
            'comment': "Cluster is not healthy"
        })

    return result


def member_add(name, **kwargs):
    '''
    Add this node to the etcd cluster
    '''
    port = kwargs.pop('port', ETCD_PEER_PORT)

    result = {'name': "member_add.{0}".format(name), 'changes': {}}

    if __salt__['caasp_etcd.member_add'](port=port):
        result.update({
            'result': True,
            'comment': "Member {0} added.".format(name)
        })
    else:
        result.update({
            'result': False,
            'comment': "Member {0} not added.".format(name)
        })

    return result


def member_remove(name, nodename=None, **kwargs):
    '''
    Remove a member from the etcd cluster

    Arguments:

    * `nodename`: (optional) the nodename for the member we
                  want the ID for. if no name is provided (or empty),
                  the local node will be used.
    '''
    result = {'name': "member_remove.{0}".format(name), 'changes': {}}

    if __salt__['caasp_etcd.member_remove'](nodename):
        result.update({
            'result': True,
            'comment': "Member {0} removed.".format(name)
        })
    else:
        result.update({
            'result': False,
            'comment': "Member {0} not removed.".format(name)
        })

    return result
