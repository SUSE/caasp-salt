# -*- coding: utf-8 -*-
'''
Module for making various web calls. Primarily designed for webhooks and the
like, but also useful for basic http testing.

CaaS Platform specific:

This module is required so we can pass options like `http_request_timeout` to
the final `query` call without having to modify the minion global configuration.

This has been implemented in Salt 2018.3.0 version:
https://github.com/saltstack/salt/commit/f72c2820f2d68f50e0919327a677f4ad8a5584b5

FIXME: Remove after we update to at least Salt 2018.3.0
'''
from __future__ import absolute_import

# Import system libs
import time

# Import salt libs
import salt.utils.http


def __virtual__():
    return "caasp_http"


def query(url, **kwargs):
    '''
    Query a resource, and decode the return data

    .. versionadded:: 2015.5.0

    CLI Example:

    .. code-block:: bash

        salt '*' http.query http://somelink.com/
        salt '*' http.query http://somelink.com/ method=POST \
            params='key1=val1&key2=val2'
        salt '*' http.query http://somelink.com/ method=POST \
            data='<xml>somecontent</xml>'
    '''
    opts = __opts__
    if 'opts' in kwargs:
        opts.update(kwargs['opts'])
        del kwargs['opts']

    return salt.utils.http.query(url=url, opts=opts, **kwargs)


def wait_for_successful_query(url, wait_for=300, **kwargs):
    '''
    Query a resource until a successful response, and decode the return data

    CLI Example:

    .. code-block:: bash

        salt '*' http.wait_for_successful_query http://somelink.com/ wait_for=160
    '''

    starttime = time.time()

    while True:
        caught_exception = None
        result = None
        try:
            result = query(url=url, **kwargs)
            if not result.get('Error') and not result.get('error'):
                return result
        except Exception as exc:
            caught_exception = exc

        if time.time() > starttime + wait_for:
            if not result and caught_exception:
                # workaround pylint bug https://www.logilab.org/ticket/3207
                raise caught_exception  # pylint: disable=E0702

            return result
