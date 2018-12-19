from __future__ import absolute_import

from salt.ext.six.moves.urllib.parse import urlparse


def __virtual__():
    return "caasp_docker"


def _get_hostname_and_port(url, default_port=None):
    parsed = urlparse(url)
    if parsed.hostname:
        hostname = parsed.hostname
        port = parsed.port
    else:
        splitted_url = url.split(':')
        hostname = splitted_url[0]
        if len(splitted_url) > 1:
            port = int(splitted_url[1])
        else:
            port = None

    res = (hostname, port or default_port)
    __utils__['caasp_log.debug']("%s parsed as %s", url, res)
    return res


def get_registries_certs(lst, default_port=5000):
    '''
    Given a list of "valid" items, return a dictionary of
    "<HOST>[:<PORT>]" -> <CERT>
    "valid" items must be get'able objects, with attributes
    "url", "cert" and (optionally) "mirrors"
    "url"s can be [<PROTO>://]<HOST>[:<PORT>]
    '''
    certs = {}

    __utils__['caasp_log.debug']('Finding certificates in: %s', lst)
    for registry in lst:
        try:
            name = registry.get('name')
            url = registry.get('url')

            cert = registry.get('cert', '')
            if cert:

                # parse the name as an URL or "host:port", and return <HOST>[:<PORT>]
                hostname, port = _get_hostname_and_port(url)
                host_port = hostname
                if port:
                    host_port += ":" + str(port)

                __utils__['caasp_log.debug']('Adding certificate for: %s', host_port)
                certs[host_port] = {'name': name, 'cert': cert}

        except Exception as e:
            __utils__['caasp_log.error']('Could not parse certificate: %s', e)

        try:
            mirrors = registry.get('mirrors', [])
            if mirrors:
                __utils__['caasp_log.debug']('Looking recursively for certificates in mirrors')
                certs_mirrors = get_registries_certs(mirrors,
                                                     default_port=default_port)
                certs.update(certs_mirrors)
        except Exception as e:
            __utils__['caasp_log.error']('Could not parse mirrors: %s', e)

    return certs


def get_certs(lst):
    '''
    Given a list of "valid" items, return a list of all the different
    certificates.
    '''
    registries_certs = get_registries_certs(lst)
    return list(set(list('%s' % value['cert'] for (key, value) in registries_certs.items())))
