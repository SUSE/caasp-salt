#
# note: in order to use these macros we must add some mine_functions:
#       network.default_route, network.interfaces
#

from __future__ import absolute_import

import logging

LOG = logging.getLogger(__name__)


def __virtual__():
    return "caasp_net"


def _get_local_id():
    return __salt__['grains.get']('id')


def _get_mine(*args, **kwargs):
    return __salt__['mine.get'](*args, **kwargs)


def get_iface_ip(iface, **kwargs):
    '''
    given an 'iface' (and an optional 'host' and list of 'ifaces'),
    return the IP address associated with 'iface'
    '''
    host = kwargs.pop('host', _get_local_id())
    ifaces = kwargs.pop('ifaces', _get_mine(host, 'network.interfaces')[host])

    return ifaces.get(iface).get('inet', [{}])[0].get('address')


def get_primary_iface(**kwargs):
    '''
    (given some optional 'host')
    return the name of the primary iface (the iface associated with the default route)
    '''
    host = kwargs.pop('host', _get_local_id())
    return _get_mine(host, 'network.default_route')[host][0]['interface']


def get_primary_ip(**kwargs):
    '''
    (given an optional minion 'host' and a list of its network interfaces, 'ifaces'),
    return the primary IP
    '''
    return get_iface_ip(get_primary_iface(**kwargs), **kwargs)


def get_primary_ips_for(compound, **kwargs):
    '''
    given a compound expression 'compound', return the primary IPs for all the
    nodes that match that expression
    '''
    res = []
    for host in _get_mine(compound, 'network.interfaces', expr_form='compound').keys():
        res.append(get_primary_ip(host=host, **kwargs))
    return res
