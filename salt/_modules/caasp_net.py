#
# note: in order to use these macros we must add some mine_functions:
#       network.default_route, network.interfaces
#

from __future__ import absolute_import


def __virtual__():
    return "caasp_net"


def _get_local_id():
    return __salt__['grains.get']('id')


def get_iface_ip(iface, **kwargs):
    '''
    given an 'iface' (and an optional 'host' and list of 'ifaces'),
    return the IP address associated with 'iface'
    '''
    host = kwargs.pop('host', _get_local_id())
    all_ifaces = __salt__['caasp_grains.get'](host, 'network.interfaces', type='glob')
    ifaces = kwargs.pop('ifaces', all_ifaces[host])

    return ifaces.get(iface).get('inet', [{}])[0].get('address')


def get_primary_iface(**kwargs):
    '''
    (given some optional 'host')
    return the name of the primary iface (the iface associated with the default route)
    '''
    host = kwargs.pop('host', _get_local_id())
    all_routes = __salt__['caasp_grains.get'](host, 'network.default_route', type='glob')
    return all_routes[host][0]['interface']


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
    all_ifaces = __salt__['caasp_grains.get'](compound, 'network.interfaces')
    for host in all_ifaces.keys():
        res.append(get_primary_ip(host=host, **kwargs))
    return res


def get_nodename(**kwargs):
    '''
    (given some optional 'host')
    return the `nodename`
    '''
    _not_provided = object()
    host = kwargs.pop('host', _not_provided)
    if host is _not_provided:
        assert __opts__['__role'] != 'master'
        return __salt__['grains.get']('nodename')
    else:
        all_nodenames = __salt__['caasp_grains.get'](host, 'nodename', type='glob')
        return all_nodenames[host]
