# note: this module is a simple proxy to the '_utils/caasp_log.py' Utility
#       module. *All* modules must use the _utils/caasp_log.py' module or it
#       will break python3. This module only exists so it can be called from
#       salt-states directly and will forward directly to the utils-module.
#


def abort(msg, *args, **kwargs):
    __utils__['caasp_log.abort'](msg, *args, **kwargs)


def error(msg, *args, **kwargs):
    __utils__['caasp_log.error'](msg, *args, **kwargs)


def warn(msg, *args, **kwargs):
    __utils__['caasp_log.warn'](msg, *args, **kwargs)


def info(msg, *args, **kwargs):
    __utils__['caasp_log.info'](msg, *args, **kwargs)


def debug(msg, *args, **kwargs):
    __utils__['caasp_log.debug'](msg, *args, **kwargs)
