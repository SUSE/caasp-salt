#
# note: in order to use these macros we must add some mine_functions:
#       network.default_route, network.interfaces
#

from __future__ import absolute_import


def __virtual__():
    return "caasp_net"


def get_iface_ip(iface, host=None, ifaces=None):
    '''
    given an 'iface' (and an optional 'host' and list of 'ifaces'),
    return the IP address associated with 'iface'
    '''
    if not ifaces:
        if not host or host == get_nodename():
            ifaces = __salt__['network.interfaces']()
        else:
            ifaces = __salt__['caasp_grains.get'](host, 'network.interfaces', type='glob')

    iface = ifaces.get(iface)
    ipv4addr = iface.get('inet', [{}])
    return ipv4addr[0].get('address')


def get_primary_iface(host=None):
    '''
    (given some optional 'host')
    return the name of the primary iface (the iface associated with the default route)
    '''
    if not host or host == get_nodename():
        default_route_lst = __salt__['network.default_route']()
        return default_route_lst[0]['interface']
    else:
        all_routes = __salt__['caasp_grains.get'](host, 'network.default_route', type='glob')
        return all_routes[host][0]['interface']


def get_primary_ip(host=None, ifaces=None):
    '''
    (given an optional minion 'host' and a list of its network interfaces, 'ifaces'),
    return the primary IP
    '''
    return get_iface_ip(iface=get_primary_iface(host=host), host=host, ifaces=ifaces)


def get_primary_ips_for(compound, **kwargs):
    '''
    given a compound expression 'compound', return the primary IPs for all the
    nodes that match that expression
    '''
    res = []
    all_ifaces = __salt__['caasp_grains.get'](compound, 'network.interfaces')
    return [get_primary_ip(host=host, **kwargs) for host in all_ifaces.keys()]


def get_nodename(host=None, **kwargs):
    '''
    (given some optional 'host')
    return the `nodename`
    '''
    if not host:
        assert __opts__['__role'] != 'master'
        return __salt__['grains.get']('nodename')
    else:
        all_nodenames = __salt__['caasp_grains.get'](host, 'nodename', type='glob')
        return all_nodenames[host]
