from __future__ import absolute_import

import json
import logging
import os.path
import shutil
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


def cp_file_to_container(container_id, source, destination):
    '''
    Copy a file from the host into a running container.

    container_id
        ID of the running container.

    source
        Full path, relative to the host, of the file to be copied.

    destination
        Full path, relative to the container, where the to copy the file.

    CLI example:

    .. code-block:: bash

        salt '*' caasp_cri.cp_file_to_container container_id='boring-elon' source='/etc/hosts' destination='/etc/hosts-caasp'
    '''
    info = ''
    success = False

    __wait_CRI_socket()

    cri = __salt__['pillar.get']('cri:name', 'docker').lower()

    if cri == 'docker':
        success, info = _docker_cp_file_to_container(container_id, source, destination)
    elif cri == 'crio':
        success, info = _crio_cp_file_to_container(container_id, source, destination)
    else:
        raise InvalidConfigError(
                'Uknown CRI specified inside of pillars: {}'.format(cri))

    return {'success': success, 'info': info}


def exec_cmd_inside_of_container(name, namespace, command):
    '''
    Exec a command inside of a running container.

    name
        Name of the container. This is checked against the ``metadata.name``
        field of a kubernetes pod.

    namespace
        Name of the namespace to search the container inside.

    command
        An array defining the command to run

    .. code-block:: bash

        salt '*' caasp_cri.exec_cmd_inside_of_container container_id='boring-elon' command='bash -c "cat /etc/hosts-caasp > /etc/hosts"'

    '''
    container_id = get_container_id(name, namespace)

    if container_id is None:
        return {'success': False,
                'info': 'Cannot find specified container'}

    cmd = "crictl --runtime-endpoint {socket} exec -s {container_id} {command}".format(
            socket=cri_runtime_endpoint(),
            container_id=container_id,
            command=command)
    result = __salt__['cmd.run_all'](cmd,
                                     output_loglevel='trace',
                                     python_shell=False)

    info = ''
    success = False

    if result['retcode'] != 0:
        info = result['stderr']
    else:
        info = result['stdout']
        success = True

    return {'success': success, 'info': info}


def cri_service_name():
    '''
    Return a string holding the name of the service identifying the CRI.

    This is used internally by our salt states to DRY them.
    '''
    if 'admin' in __salt__['grains.get']('roles', []):
        return 'docker'

    cri = __salt__['pillar.get']('cri:name', 'docker').lower()

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

    cri = __salt__['pillar.get']('cri:name', 'docker').lower()

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

    cri = __salt__['pillar.get']('cri:name', 'docker').lower()

    if cri == 'docker':
        return '/var/run/dockershim.sock'
    elif cri == 'crio':
        return '/var/run/crio/crio.sock'
    else:
        raise InvalidConfigError(
                'Uknown CRI specified inside of pillars: {}'.format(cri))


def _docker_cp_file_to_container(container_id, source, destination):
    '''
    Use ``docker cp`` to copy a file from the host into a running container
    managed by docker
    '''

    cmd = 'docker cp {source} {container_id}:{destination}'.format(
            source=source,
            container_id=container_id,
            destination=destination)
    result = __salt__['cmd.run_all'](cmd,
                                     output_loglevel='trace',
                                     python_shell=False)

    if result['retcode'] != 0:
        return (False, result['stderr'])

    return (True, '')


def _crio_cp_file_to_container(container_id, source, destination):
    '''
    Use ``podman`` to copy a file from the host into a running container
    managed by crio.
    '''

    cmd = 'podman mount {container_id}'.format(
            container_id=container_id)
    result = __salt__['cmd.run_all'](cmd,
                                     output_loglevel='trace',
                                     python_shell=False)

    if result['retcode'] != 0:
        return (
                False,
                'Error mounting container fs with podman: {}'.format(
                    result['stderr']))

    try:
        if os.path.isdir(source):
            shutil.copytree(source, destination)
        else:
            shutil.copy(source, destination)
    except OSError as e:
        return(
                False,
                'Error while copying file(s): {}'.format(e))

    cmd = 'podman unmount {container_id}'.format(
            container_id=container_id)
    result = __salt__['cmd.run_all'](cmd,
                                     output_loglevel='trace',
                                     python_shell=False)

    if result['retcode'] != 0:
        return (
                False,
                'Error unmounting container fs with podman: {}'.format(
                    result['stderr']))

    return (True, '')


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
