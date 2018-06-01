from __future__ import absolute_import

import time


def running_stable(name, enable=None, sig=None, init_delay=None, successful_retries_in_a_row=50,
                   max_retries=300, delay_between_retries=0.1, **kwargs):
    '''
    Ensure that the service is running in a stable manner

    name
        The name of the init or rc script used to manage the service

    enable
        Set the service to be enabled at boot time, True sets the service to
        be enabled, False sets the named service to be disabled. The default
        is None, which does not enable or disable anything.

    sig
        The string to search for when looking for the service process with ps

    init_delay
        Some services may not be truly available for a short period after their
        startup script indicates to the system that they are. Provide an
        'init_delay' to specify that this state should wait an additional given
        number of seconds after a service has started before returning. Useful
        for requisite states wherein a dependent state might assume a service
        has started but is not yet fully initialized.

    successful_retries_in_a_row
        The number of checks that need to be successful in a row to consider
        this service is running.

    max_retries
        The total number of times to check if a service is running.

    delay_between_retries
        The delay in seconds between checks.

    .. note::
        ``watch`` can be used with caasp_service.running to restart a service when
         another state changes ( example: a file.managed state that creates the
         service's config file ). More details regarding ``watch`` can be found
         in the :ref:`Requisites <requisites>` documentation.
    '''
    ret = {'name': name,
           'changes': {},
           'result': False,
           'comment': ''}

    __states__['service.running'](name=name,
                                  enable=enable,
                                  sig=sig,
                                  init_delay=init_delay)

    latest_pid = None
    current_successful_retries_in_a_row = 0
    max_current_successful_retries_in_a_row = 0
    for retry in range(max_retries):
        pid = __salt__['service.status'](name=name,
                                         sig=sig)

        if pid and (not latest_pid or latest_pid == pid):
            current_successful_retries_in_a_row += 1
        else:
            current_successful_retries_in_a_row = 0

        latest_pid = pid
        max_current_successful_retries_in_a_row = max(
            max_current_successful_retries_in_a_row, current_successful_retries_in_a_row)

        if current_successful_retries_in_a_row == successful_retries_in_a_row:
            ret['result'] = True
            ret['comment'] = 'Service {0} is up after {1} total retries. Including {2} retries in a row'.format(
                name, retry + 1, successful_retries_in_a_row)
            break

        if delay_between_retries:
            time.sleep(delay_between_retries)

    if not ret['result']:
        ret['comment'] = 'Service {0} is dead after {1} total retries. Expected {2} success in a row, got {3} as maximum'.format(
            name, max_retries, successful_retries_in_a_row, max_current_successful_retries_in_a_row)

    return ret
