from __future__ import absolute_import

import logging

log = logging.getLogger(__name__)


class ExecutionAborted(Exception):
    pass


def abort(*args, **kwargs):
    '''
    Abort the Salt execution with an error
    '''
    # TODO: use the builtin function (https://docs.saltstack.com/en/latest/topics/jinja/index.html#logs)
    #       once we Salt>2017.7.0
    log.error(*args, **kwargs)
    raise ExecutionAborted()


def error(*args, **kwargs):
    '''
    Log a error message
    '''
    # TODO: use the builtin function (https://docs.saltstack.com/en/latest/topics/jinja/index.html#logs)
    #       once we Salt>2017.7.0
    log.error(*args, **kwargs)


def warn(*args, **kwargs):
    '''
    Log a warning message
    '''
    # TODO: use the builtin function (https://docs.saltstack.com/en/latest/topics/jinja/index.html#logs)
    #       once we Salt>2017.7.0
    log.warn(*args, **kwargs)


def debug(*args, **kwargs):
    '''
    Log a debug message
    '''
    # TODO: use the builtin function (https://docs.saltstack.com/en/latest/topics/jinja/index.html#logs)
    #       once we Salt>2017.7.0
    log.debug(*args, **kwargs)
