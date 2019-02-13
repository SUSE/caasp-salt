from __future__ import absolute_import

import socket
import os

# TODO: in Python 3 there is an ipaddress module which works out of the box. In
# fact, Salt is using this module when running in Python 3. For Python 2 Salt
# is using a custom implementation, which is buggy on some checks. Thus,
# whenever we jump into Python3, we should consider using either
# salt._compat.ipaddress, or the module from Python 3.


def __virtual__():
    return "caasp_filters"


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
        socket.inet_pton(socket.AF_INET, ip)
        return True
    except socket.error:
        return False


def is_ipv6(ip):
    '''
    Returns a bool telling if the value passed to it was a valid IPv6 address
    '''
    try:
        socket.inet_pton(socket.AF_INET6, ip)
        return True
    except socket.error:
        return False


def get_max(seq):
    # TODO: use the builtin filter
    # (https://docs.saltstack.com/en/latest/topics/jinja/index.html#max)
    #       once we Salt>2017.7.0
    return max(seq)


def basename(filename):
    '''
    Wrapper around os.path.basename for use in jinja templates.
    '''
    # Return the last path segment
    return os.path.basename(filename)
