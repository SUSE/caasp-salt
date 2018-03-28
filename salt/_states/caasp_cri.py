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
