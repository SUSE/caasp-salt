#!/usr/bin/python

import salt.grains.core

assert '__opts__' in globals()
salt.grains.core.__opts__ = __opts__


def caasp_nodename():
    """
    Override core.hostname grain to provide lowercased items
    localhost, fqdn, host, domain, nodename
    """
    hn = salt.grains.core.hostname()
    os_data = salt.grains.core.os_data()
    return dict(
        domain = hn['domain'].lower(),
        fqdn = hn['fqdn'].lower(),
        host = hn['host'].lower(),
        localhost = hn['localhost'].lower(),
        nodename = os_data['nodename'].lower()
    )
