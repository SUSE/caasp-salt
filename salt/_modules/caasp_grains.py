from __future__ import absolute_import


def __virtual__():
    return "caasp_grains"


# an exported (to the mine) grain used for getting ids
DEFAULT_GRAIN = 'nodename'


def get(expr, grain=DEFAULT_GRAIN, type='compound'):
    if __opts__['__role'] == 'master':
        # 'mine.get' is not available in the master: it returns nothing
        # in that case, we should use "saltutil.runner"... uh?
        return __salt__['saltutil.runner']('mine.get',
                                           tgt=expr,
                                           fun=grain, tgt_type=type)
    else:
        return __salt__['mine.get'](expr, grain, tgt_type=type)
