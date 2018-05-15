# -*- coding: utf-8 -*-
'''
Beacon to monitor default network adapter setting changes on Linux
'''

from salt.beacons import network_settings

import logging
log = logging.getLogger(__name__)

__virtual_name__ = 'default_network_interface_settings'


def __virtual__():
    if network_settings.__virtual__():
        return __virtual_name__
    return False


def __validate__(config):
    return network_settings.__validate__(config)


def beacon(config):
    '''
    Watch for changes on network settings on the gateway interface.

    By default, the beacon will emit when there is a value change on one of the
    settings on watch. The config also support the onvalue parameter for each
    setting, which instruct the beacon to only emit if the setting changed to the
    value defined.

    Example Config

    .. code-block:: yaml

        beacons:
          default_network_interface_settings:
            interval: 5
            watch:
              ipaddr:
              promiscuity:
                onvalue: 1
    '''

    default_interface = __salt__['network.default_route']()[0]['interface']

    return network_settings.beacon({default_interface: config['watch']})
