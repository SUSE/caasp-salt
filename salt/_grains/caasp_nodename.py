#!/usr/bin/python

import salt.grains.core

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
