from __future__ import absolute_import

import logging

log = logging.getLogger(__name__)


def stop_container_and_wait(name, namespace, timeout=60, **kwargs):
    '''
    Stop the running container named ``name`` running inside of
    the specified ``namespace``.

    Then waits for kubelet to bring up a new instance of the same
    container.

    name
        Name of the container. This is checked against the ``metadata.name``
        field of a kubernetes pod.

    namespace
        Name of the namespace to search the container inside.

    timeout
        If the container has not been restarted after timeout seconds, return
        with a failure.

        By default a 60 seconds timeout is applied.

    .. code-block:: yaml

    kube_system_haproxy:
      caasp_cri.stop_container_and_wait:
        name: haproxy
        namespace: kube-system
        timeout: 120
    '''

    ret = {'name': name,
           'namespace': namespace,
           'changes': {},
           'result': False,
           'comment': ''}

    stopped = __salt__['caasp_cri.stop_container'](name, namespace, **kwargs)

    if not stopped:
        log.debug('CaaS: {namespace}.{name} container was not found running'.format(
            namespace=namespace,
            name=name))

    return wait_for_container(name, namespace, timeout, **kwargs)


def wait_for_container(name, namespace, timeout=60, **kwargs):
    '''
    Wait for a container to be up and running.

    name
        Name of the container. This is checked against the ``metadata.name``
        field of a kubernetes pod.

    namespace
        Name of the namespace to search the container inside.

    timeout
        If the container is not running after ``timeout`` seconds, return
        with a failure.

        By default a 60 seconds timeout is applied.

    .. code-block:: yaml

    kube_system_haproxy:
      caasp_cri.wait_for_container:
        name: haproxy
        namespace: kube-system
        timeout: 120
    '''

    ret = {'name': name,
           'namespace': namespace,
           'changes': {},
           'result': False,
           'comment': ''}


    running = __salt__['caasp_cri.wait_for_container'](name,
                                                       namespace,
                                                       timeout,
                                                       **kwargs)

    if running:
        ret['result'] = True
        ret['comment'] = '{namespace}.{container} successfully restarted'.format(
                namespace=namespace,
                container=name)
    else:
        ret['comment'] = '{namespace}.{container} was not restarted by kubelet within the given time'.format(
            namespace=namespace,
            container=name)

    return ret


def cp_file_to_container(name, namespace, source, destination, **kwargs):
    '''
    Copy a file from the host into a running container.

    name
        Name of the container. This is checked against the ``metadata.name``
        field of a kubernetes pod.

    namespace
        Name of the namespace to search the container inside.

    source
        Full path, relative to the host, of the file to be copied.

    destination
        Full path, relative to the container, where the to copy the file.

    .. code-block:: yaml

    update-ha-proxy-hosts:
      caasp_cri.cp_file_to_container:
        name: haproxy
        namespace: kube-system
        source: /etc/hosts
        destination: /etc/hosts-caasp
    '''

    ret = {'name': name,
           'namespace': namespace,
           'source': source,
           'destination': destination,
           'changes': {},
           'result': False,
           'comment': ''}


    container_id = __salt__['caasp_cri.get_container_id'](name,
                                                          namespace,
                                                          **kwargs)

    if container_id is None:
        ret['comment'] = '{namespace}.{container} is not running'.format(
                namespace=namespace,
                container=name)
        return ret

    file_copied, error = __salt__['caasp_cri.cp_file_to_container'](
            container_id,
            source,
            destination,
            **kwargs)

    if file_copied:
        ret['result'] = True
        ret['comment'] = 'File successfully copied into container'
    else:
        ret['comment'] = error

    return ret


def exec_cmd_inside_of_container(name, namespace, command, **kwargs):
    '''
    Exec a command inside of a running container.

    name
        Name of the container. This is checked against the ``metadata.name``
        field of a kubernetes pod.

    namespace
        Name of the namespace to search the container inside.

    command
        The command to run

    .. code-block:: yaml

    update-velum-hosts2:
      caasp_cri.exec_cmd_inside_of_container:
        name: velum-dashboard
        namespace: kube-system
        cmd: 'bash -c "cat /etc/hosts-caasp > /etc/hosts"'
    '''

    ret = {'name': name,
           'namespace': namespace,
           'command': command,
           'changes': {},
           'result': False,
           'comment': ''}


    container_id = __salt__['caasp_cri.get_container_id'](name,
                                                          namespace,
                                                          **kwargs)

    if container_id is None:
        ret['comment'] = '{namespace}.{container} is not running'.format(
                namespace=namespace,
                container=name)
        return ret

    cmd_run, details = __salt__['caasp_cri.exec_cmd_inside_of_container'](
            container_id,
            command,
            **kwargs)

    if cmd_run:
        ret['result'] = True
        ret['comment'] = 'Command successfully run: {}'.format(details)
    else:
        ret['comment'] = details

    return ret
