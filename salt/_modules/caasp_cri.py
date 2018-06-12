from __future__ import absolute_import

import json
import time

from salt.exceptions import CommandExecutionError

from caasp_log import debug

try:
    from salt.exceptions import InvalidConfigError
except ImportError:
    from salt.exceptions import SaltException

    class InvalidConfigError(SaltException):
        '''
        Not yet defined by this version of salt
        '''


class CRIRuntimeException(Exception):
    pass


_ROLES_REQUIRING_DOCKER = ('admin', 'ca')
_SUPPORTED_CRIS = ('docker', 'crio')
_BUSY_LOOP_INTERVAL = 0.3


def __virtual__():
    return "caasp_cri"


def cri_name():
    '''
    Calculate the CRI name by looking at the pillar set by the user.

    Forces the 'docker' CRI to be used on the nodes that have certain roles,
    this is needed because salt pillars exposed by Velum have precedence
    over everything.
    '''

    if needs_docker():
        return 'docker'

    return __salt__['pillar.get']('cri:chosen', 'docker').lower()


def get_container_id(name, namespace):
    '''
    Return the ID of the running container named ``name`` running inside of
    the specified ``namespace``.

    Returns ``None`` if no running container was found matching the criteria.

    name
        Name of the container. This is checked against the ``metadata.name``
        field of a kubernetes pod.

    namespace
        Name of the namespace to search the container inside.

    CLI example:

    .. code-block:: bash

        salt '*' caasp_cri.get_container_id name='haproxy' namespace='kube-system'
    '''

    __wait_CRI_socket()
    cmd = "crictl --runtime-endpoint {socket} ps -o json".format(
        socket=cri_runtime_endpoint()
    )

    result = __salt__['cmd.run_all'](cmd,
                                     output_loglevel='trace',
                                     python_shell=False)

    if result['retcode'] != 0:
        debug('"crictl ps" failed, with retcode %d', result['retcode'])
        raise CommandExecutionError(
            'Could not invoke crictl',
            info={'errors': [result['stderr']]}
        )

    try:
        ps_data = json.loads(result['stdout'])
    except Exception as e:
        raise CRIRuntimeException('Cannot parse `crictl ps` json output: {}'.
                                  format(e.message))

    if 'containers' not in ps_data:
        # this happens when no containers are running
        debug('no ps data obtained in get_container_id()')
        return None

    for container in ps_data['containers']:
        if container['metadata']['name'] == name and \
           container['labels']['io.kubernetes.pod.namespace'] == namespace:
            return container['id']

    return None


def stop_container(name, namespace, ignore_errors=True):
    '''
    Stop the running container named ``name`` running inside of
    the specified ``namespace``.

    Return ``True`` when the container has been successfully stopped.
    Returns ``False`` when no running container matching the criteria has been
    found.
    Raises an exception when something goes wrong when trying to stop the
    container, unless ``ignore_errors`` is set to ``True``.

    name
        Name of the container. This is checked against the ``metadata.name``
        field of a kubernetes pod.

    namespace
        Name of the namespace to search the container inside.

    ignore_errors
        Ignore errors the container might raise when stopped in a forced way.
        By default set to ``True``.


    CLI example:

    .. code-block:: bash

        salt '*' caasp_cri.stop_container name='haproxy' namespace='kube-system'
    '''

    container_id = get_container_id(name, namespace)

    if container_id is None:
        return False

    cmd = "crictl --runtime-endpoint {socket} stop {container_id}".format(
        socket=cri_runtime_endpoint(),
        container_id=container_id
    )
    result = __salt__['cmd.run_all'](cmd,
                                     output_loglevel='trace',
                                     python_shell=False)

    if result['retcode'] != 0 and not ignore_errors:
        raise CommandExecutionError(
            'Something went wrong while stopping the container',
            info={'errors': [result['stderr']]}
        )

    return True


def wait_for_container(name, namespace, timeout):
    '''
    Wait for a container to be up and running.

    Return ``True`` if the container is up and running, ``False``
    if the container wasn't found after ``timeout`` seconds.

    name
        Name of the container. This is checked against the ``metadata.name``
        field of a kubernetes pod.

    namespace
        Name of the namespace to search the container inside.

    timeout
        Stop waiting for the container to be up and running after ``timeout``
        seconds elapsed.

    CLI example:

    .. code-block:: bash

        salt '*' caasp_cri.wait_for__container name='haproxy' namespace='kube-system'
    '''
    expire = time.time() + timeout

    while time.time() < expire:
        if get_container_id(name, namespace):
            return True
        time.sleep(_BUSY_LOOP_INTERVAL)

    return False


def cri_runtime_endpoint():
    '''
    Return the path to the socket required by crictl to communicate
    with the CRI
    '''
    return __pillar__['cri'][cri_name()]['socket']


def __wait_CRI_socket():
    '''
    Ensures the CRI socket is ready before executing the decorated function.

    This is needed because crictl doesn't block until the
    CRI socket is ready. This can lead to some edge cases
    at bootstrap time, where the CRI is not yet running
    but some state interacting with it is applied.
    '''
    timeout = int(__salt__['pillar.get']('cri:socket_timeout', '20'))
    expire = time.time() + timeout
    errors = {'attempts': []}

    debug('ensuring the cri socket is ready...')
    while time.time() < expire:
        cmd = "crictl --runtime-endpoint {socket} info".format(
            socket=cri_runtime_endpoint()
        )

        result = __salt__['cmd.run_all'](cmd,
                                         output_loglevel='trace',
                                         python_shell=False)
        if result['retcode'] == 0:
            debug('cri socket ready')
            return

        errors['attempts'].append(result)

        time.sleep(_BUSY_LOOP_INTERVAL)

    raise CommandExecutionError(
        'CRI socket did not become ready',
        info=errors
    )


def needs_docker():
    '''
    Return true if the minion must use docker as CRI despite of what is
    configured inside of the pillars.
    '''
    node_roles = __salt__['grains.get']('roles', [])
    return any(role in _ROLES_REQUIRING_DOCKER for role in node_roles)
