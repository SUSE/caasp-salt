import platform

import salt.grains.core


def caasp_nodename():
    """
    Override core.hostname grain to provide lowercased items
    localhost, fqdn, host, domain, nodename
    """
    hn = salt.grains.core.hostname()
    raw_nodename = platform.uname()[1]

    return dict(
        domain=hn['domain'].lower(),
        fqdn=hn['fqdn'].lower(),
        host=hn['host'].lower(),
        localhost=hn['localhost'].lower(),
        nodename=raw_nodename.lower()
    )
