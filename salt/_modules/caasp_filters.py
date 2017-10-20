from __future__ import absolute_import
from salt._compat import ipaddress


def is_ip(ip):
    '''
    Returns a bool telling if the passed IP is a valid IPv4 or IPv6 address.
    '''
    return is_ipv4(ip) or is_ipv6(ip)


def is_ipv4(ip):
    '''
    Returns a bool telling if the value passed to it was a valid IPv4 address
    '''
    try:
        return ipaddress.ip_address(ip).version == 4
    except ValueError:
        return False


def is_ipv6(ip):
    '''
    Returns a bool telling if the value passed to it was a valid IPv6 address
    '''
    try:
        return ipaddress.ip_address(ip).version == 6
    except ValueError:
        return False
