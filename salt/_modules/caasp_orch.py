from __future__ import absolute_import


def __virtual__():
    return "caasp_orch"


def sync_all():
    '''
    Syncronize everything before starting a new orchestration
    '''
    __utils__['caasp_log.debug']('orch: refreshing all')
    __salt__['saltutil.sync_all'](refresh=True)

    __utils__['caasp_log.debug']('orch: synchronizing the mine')
    __salt__['saltutil.runner']('mine.update', tgt='*', clear=True)
