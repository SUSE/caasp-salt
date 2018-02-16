# -*- coding: utf-8 -*-
'''
A module that adds data to the Pillar structure retrieved by an http request made to Velum

Configuring the VELUM ext_pillar
================================

Set the following Salt config to setup Velum as an external pillar source:

.. code-block:: json

  ext_pillar:
    - velum:
        url: https://velum.example.com/internal-api/v1/pillar?version=1
        ca_bundle: /some/bundle.crt
        username: username
        password: secret

This pillar module will cache the results from successful requests into the salt cache subsystem,
that will allow to serve this cached content in case Velum is not available.
'''

# Import python libs
from __future__ import absolute_import
import logging

# Import Salt libs
import salt.ext.six as six
import salt.cache

import os

# Globals
log = logging.getLogger(__name__)

def __virtual__():
    log.info("Loaded velum pillar module")
    return "velum"


def ext_pillar(minion_id,
               pillar,  # pylint: disable=W0613
               url=None,
               ca_bundle=None,
               username=None,
               password=None):
    '''
    Read pillar data from HTTP response.

    :param url String to make request
    :param ca_bundle Path to CA bundle
    :param username Username for basic-auth
    :param password Password for basic-auth
    :returns dict with pillar data to add
    :returns empty if error
    '''
    log.debug("Fetching velum pillar data")

    cache = salt.cache.Cache(__opts__)

    if username is None:
        with open(os.environ['VELUM_INTERNAL_API_USERNAME_FILE'], 'r') as f:
            username = f.read().strip()

    if password is None:
        with open(os.environ['VELUM_INTERNAL_API_PASSWORD_FILE'], 'r') as f:
            password = f.read().strip()

    data = __salt__['http.query'](url=url,
                                  ca_bundle=ca_bundle,
                                  username=username,
                                  password=password,
                                  decode=True,
                                  decode_type='json')

    if 'dict' in data:
        cache.store('caasp/pillar', minion_id, data['dict'])
        return data['dict']
    elif cache.contains('caasp/pillar', minion_id):
        log.warning('Serving pillar from cache for minion {0}, since {1} was not available'.format(minion_id, url))
        return cache.fetch('caasp/pillar', minion_id)

    log.error('Error caught on query to {0}. More Info:\n'.format(url))
    for k, v in six.iteritems(data):
        log.error(k + ' : ' + v)

    return {}
