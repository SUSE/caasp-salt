from __future__ import absolute_import

from salt._compat import ipaddress


def __virtual__():
    return "caasp_filters"


def is_ip(ip):
    '''
    Returns a bool telling if the passed IP is a valid IPv4 or IPv6 address.
    '''
    # TODO: use the builtin filter (https://docs.saltstack.com/en/latest/topics/jinja/index.html#is-ip)
    #       once we Salt>2017.7.0
    return is_ipv4(ip) or is_ipv6(ip)


def is_ipv4(ip):
    '''
    Returns a bool telling if the value passed to it was a valid IPv4 address
    '''
    # TODO: use the builtin filter (https://docs.saltstack.com/en/latest/topics/jinja/index.html#is-ipv4)
    #       once we Salt>2017.7.0
    try:
        return ipaddress.ip_address(ip).version == 4
    except ValueError:
        return False


def is_ipv6(ip):
    '''
    Returns a bool telling if the value passed to it was a valid IPv6 address
    '''
    # TODO: use the builtin filter (https://docs.saltstack.com/en/latest/topics/jinja/index.html#is-ipv6)
    #       once we Salt>2017.7.0
    try:
        return ipaddress.ip_address(ip).version == 6
    except ValueError:
        return False


def get_max(seq):
    # TODO: use the builtin filter (https://docs.saltstack.com/en/latest/topics/jinja/index.html#max)
    #       once we Salt>2017.7.0
    return max(seq)
