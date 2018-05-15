from __future__ import absolute_import


def __virtual__():
    return "caasp_grains"


# default grain name, used for getting node IDs
# DEPRECATED: this will be removed in CaaSP 3.0
_GRAIN_NAME = 'caasp_fqdn'


def get(expr, grain=_GRAIN_NAME, type='compound'):
    if __opts__['__role'] == 'master':
        # 'mine.get' is not available in the master: it returns nothing
        # in that case, we should use "saltutil.runner"... uh?
        return __salt__['saltutil.runner']('mine.get',
                                           tgt=expr,
                                           fun=grain, tgt_type=type)
    else:
        return __salt__['mine.get'](expr, grain, expr_form=type)
