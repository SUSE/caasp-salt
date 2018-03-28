from __future__ import absolute_import

import json
import logging
import os.path
import time
from salt.exceptions import CommandExecutionError

try:
    from salt.exceptions import InvalidConfigError
except ImportError:
    from salt.exceptions import SaltException

    class InvalidConfigError(SaltException):
        '''
        Not yet defined by this version of salt
        '''

log = logging.getLogger(__name__)


def __virtual__():
    return "caasp_cri"


def cri_name():
    '''
    Calculate the CRI name by looking at the pillar set by the user.

    Forces the 'docker' CRI to be used on the nodes that have certain roles,
    this is needed because salt pillars exposed by Velum have precedence
    over everything.
    '''
    roles_requiring_docker = ('admin', 'ca')

    node_roles = __salt__['grains.get']('roles', [])
    cri = __salt__['pillar.get']('cri:name', 'docker').lower()

    for role in node_roles:
        if role in roles_requiring_docker:
            return 'docker'

    return cri


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
            socket=cri_runtime_endpoint())
    result = __salt__['cmd.run_all'](cmd,
                                     output_loglevel='trace',
                                     python_shell=False)

    if result['retcode'] != 0:
        raise CommandExecutionError(
                'Could not invoke crictl',
                info={'errors': [result['stderr']]}
            )

    ps_data = json.loads(result['stdout'])
    if 'containers' not in ps_data:
        # this happens when no containers are running
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
            container_id=container_id)
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
        if get_container_id(name, namespace) is not None:
            return True
        time.sleep(0.3)

    return False


def cri_service_name():
    '''
    Return a string holding the name of the service identifying the CRI.

    This is used internally by our salt states to DRY them.
    '''
    if 'admin' in __salt__['grains.get']('roles', []):
        return 'docker'

    cri = cri_name()

    if cri == 'docker':
        return 'docker'
    elif cri == 'crio':
        return 'crio'
    else:
        raise InvalidConfigError(
                'Uknown CRI specified inside of pillars: {}'.format(cri))


def cri_salt_state_name():
    '''
    Return a string holding the name of the salt state that manages the CRI.

    This is used internally by our salt states to DRY them.
    '''
    return cri_service_name()


def cri_package_name():
    '''
    Return a string holding the name of the package providing the CRI

    This is used internally by our salt states to DRY them.
    '''
    if 'admin' in __salt__['grains.get']('roles', []):
        return 'docker'

    cri = cri_name()

    if cri == 'docker':
        return 'docker'
    elif cri == 'crio':
        return 'cri-o'
    else:
        raise InvalidConfigError(
                'Uknown CRI specified inside of pillars: {}'.format(cri))


def cri_runtime_endpoint():
    '''
    Return the path to the socket required by crictl to communicate
    with the CRI
    '''
    if 'admin' in __salt__['grains.get']('roles', []):
        return '/var/run/dockershim.sock'

    cri = cri_name()

    if cri == 'docker':
        return '/var/run/dockershim.sock'
    elif cri == 'crio':
        return '/var/run/crio/crio.sock'
    else:
        raise InvalidConfigError(
                'Uknown CRI specified inside of pillars: {}'.format(cri))


def __wait_CRI_socket():
    '''
    Ensures the CRI socket is ready before executing the decorated function.

    This is needed because crictl doesn't block until the
    CRI socket is ready. This can lead to some edge cases
    at bootstrap time, where the CRI is not yet running
    but some state interacting with it is applied.
    '''

    socket = cri_runtime_endpoint()
    timeout = int(__salt__['pillar.get']('cri:socket_timeout', '10'))
    expire = time.time() + timeout

    while time.time() < expire:
        if os.path.exists(socket):
            return
        time.sleep(0.3)
