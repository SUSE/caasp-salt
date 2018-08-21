from __future__ import absolute_import


def migration(name):
    '''
    Perform a product migration

    .. code-block:: yaml

    do_a_migration:
      caasp_txupdate.migration
    '''

    ret = {'name': name,
           'result': False,
           'changes': {},
           'comment': ''}

    running = __salt__['caasp_txupdate.migration']()

    if running:
        ret['result'] = True
        ret['comment'] = 'transactional-update successfully ran'
    else:
        ret['comment'] = 'transactional-update failed to run'

    return ret
