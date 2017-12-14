from __future__ import absolute_import

import logging
from urlparse import urlparse

LOG = logging.getLogger(__name__)


def __virtual__():
    return "caasp_docker"


def get_hostname_and_port(url, default_port=None):
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
    LOG.debug("%s parsed as %s", url, res)
    return res


def get_hostname_and_port_str(url, default_port=None):
    hostname, port = get_hostname_and_port(url, default_port=default_port)
    host_port = hostname
    if port:
        host_port += ":" + str(port)
    return host_port


def get_registries_certs(lst, default_port=5000):
    '''
    Given a list of "valid" items, return a dictionay of
    "<HOST>[:<PORT>]" -> <CERT>
    "valid" items must be get'able objects, with attributes
    "url", "cert" and (optional) "mirrors"
    "url"s can be [<PROTO>://]<HOST>[:<PORT>]
    '''
    certs = {}

    LOG.debug('Finding certificates in: %s', lst)
    for registry in lst:
        url = registry.get('url')
        cert = registry.get('cert', '')
        if len(cert) > 0:

            # parse the name as an URL or "host:port", and return <HOST>[:<PORT>]
            hostname, port = get_hostname_and_port(url)
            host_port = hostname
            if port:
                host_port += ":" + str(port)

            LOG.debug('Adding certificate for: %s', host_port)
            certs[host_port] = cert

            if port:
                if port == default_port:
                    # When using the standar port (5000), if the user introduces
                    # "my-registry:5000" as a trusted registry, he/she will be able
                    # to do "docker pull my-registry:5000/some/image" but not
                    # "docker pull my-registry/some/image".
                    # So we must also create the "ca.crt" for "my-registry"
                    # as he/she could just access "docker pull my-registry/some/image",
                    # and Docker would fail to find "my-registry/ca.crt"
                    name = hostname
                    LOG.debug(
                        'Using default port: adding certificate for "%s" too', name)
                    certs[name] = cert
            else:
                # the same happens if the user introduced a certificate for
                # "my-registry": we must fix the "docker pull my-registry:5000/some/image" case...
                name = hostname + ':' + str(default_port)
                LOG.debug('Adding certificate for default port, "%s", too', name)
                certs[name] = cert

        mirrors = registry.get('mirrors', [])
        if len(mirrors) > 0:
            LOG.debug('Looking recursively for certificates in mirrors')
            certs_mirrors = get_registries_certs(mirrors,
                                                 default_port=default_port)
            certs.update(certs_mirrors)

    return certs
