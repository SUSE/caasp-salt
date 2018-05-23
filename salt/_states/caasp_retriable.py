from __future__ import absolute_import
import time
from salt.ext.six.moves import range


def retry(name, target, retry={}, **kwargs):
    '''
    Wraps an existing salt state into a retriable form.

    name
        A user-defined name.

    target
        Name of the salt state to invoke.

    retry
        This allows you to provide `attempts` and `interval`, what will retry
        the command as much ``attempts`` times, separated by `interval`
        seconds. By default performs 1 attempt with a 1 second interval.

    All other arguments are passed to the orginal salt state.

    '''

    retry_ = {'attempts': 1, 'interval': 1}
    retry_.update(retry)

    ret = None

    for attempt in range(retry_['attempts']):
        try:
            ret = __states__[target](name=name, **kwargs)
        except BaseException as e:
            ret = {'result': False, 'changes': False, 'comment': 'Exception raised: {0}'.format(e)}

        if ret['result']:
            return {
                'name': "caasp_retriable.{0}.{1}".format(name, target),
                'changes': ret['changes'],
                'result': True,
                'comment': "Command executed succesfully after {0} attempts. "
                "Last output: {1}".format(attempt + 1, ret['comment'])}

        if attempt + 1 == retry_['attempts']:
            break

        if retry_['interval'] > 0:
            time.sleep(retry_['interval'])

    return {
        'name': "caasp_retriable.{0}.{1}".format(name, target),
        'changes': ret['changes'],
        'result': False,
        'comment': "Command failed after {0} attempts. "
                   "Last output: {1} "
                   "Params: {2}".format(
                       retry_['attempts'],
                       ret['comment'],
                       kwargs)}
