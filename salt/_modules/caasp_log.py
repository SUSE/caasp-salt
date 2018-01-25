from __future__ import absolute_import

import logging

log = logging.getLogger(__name__)


def error(*args, **kwargs):
    '''
    Log a error message
    '''
    # TODO: use the builtin function (https://docs.saltstack.com/en/latest/topics/jinja/index.html#logs)
    #       once we Salt>2017.7.0
    log.error(*args, **kwargs)
