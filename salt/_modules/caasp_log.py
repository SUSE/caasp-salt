# note: this module can be directly imported from other
#       Salt modules. Do not do the same for other modules:
#       use __salt__['caasp_module.function'](args)
#
from __future__ import absolute_import

import logging

from salt.exceptions import SaltException

log = logging.getLogger('CaaS')


_CAAS_PREFIX = '[CaaS]: '


class ExecutionAborted(SaltException):
    pass


def abort(msg, *args, **kwargs):
    '''
    Abort the Salt execution with an error
    '''
    error(msg, *args, **kwargs)
    raise ExecutionAborted(msg % args)


def error(msg, *args, **kwargs):
    '''
    Log a error message
    '''
    log.error(_CAAS_PREFIX + msg % args, **kwargs)


def warn(msg, *args, **kwargs):
    '''
    Log a warning message
    '''
    log.warn(_CAAS_PREFIX + msg % args, **kwargs)


def info(msg, *args, **kwargs):
    '''
    Log an info message
    '''
    log.info(_CAAS_PREFIX + msg % args, **kwargs)


def debug(msg, *args, **kwargs):
    '''
    Log a debug message
    '''
    log.debug(_CAAS_PREFIX + msg % args, **kwargs)
