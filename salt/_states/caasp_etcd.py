from __future__ import absolute_import

import logging
import os

import salt.exceptions
import salt.utils

log = logging.getLogger(__name__)

# default number of trials for etcdctl
DEFAULT_ATTEMPTS = 10

# ... and the interval between them
DEFAULT_ATTEMPTS_INTERVAL = 2


def etcdctl(name, retry={}, **kwargs):
    '''
    Run an etcdctl command
    '''
    retry_ = {'attempts': DEFAULT_ATTEMPTS,
              'interval': DEFAULT_ATTEMPTS_INTERVAL,
              'until': None}
    retry_.update(retry)

    args = __salt__['caasp_etcd.get_etcdctl_args_str']()
    cmd = 'etcdctl {} {}'.format(args, name)
    log.debug('CaaS: running etcdctl as: %s', cmd)

    return __states__['caasp_cmd.run'](name=cmd,
                                       retry=retry_,
                                       **kwargs)


def healthy(name, **kwargs):
    log.debug('CaaS: checking etcd health')
    return etcdctl(name='cluster-health', **kwargs)


def member_add(name, **kwargs):
    '''
    Add this node to the etcd cluster
    '''
    this_id = __salt__['grains.get']('id')
    this_peer_url = 'https://' + __salt__['grains.get']('nodename') + ':2380'

    name = 'member add {} {}'.format(this_id, this_peer_url)
    log.debug('CaaS: adding etcd member')
    return etcdctl(name=name, **kwargs)

    # once the member has been added to the cluster, we
    # must make sure etcd joins an "existing" cluster.
    # so we must set ETCD_INITIAL_CLUSTER_STATE=existing
    # or, otherwise, etcd will refuse to join... (facepalm)


def member_remove(name, **kwargs):
    '''
    Remove this node from the etcd cluster
    '''
    this_member_id = __salt__['caasp_etcd.get_member_id']()
    if not this_member_id:
        return {
            'name': "member_remove.{0}".format(name),
            'result': False,
            'comment': "Could not obtain member id."
        }

    name = 'member remove {}'.format(this_member_id)
    log.debug('CaaS: removing etcd member %s', this_member_id)
    return etcdctl(name=name, **kwargs)
