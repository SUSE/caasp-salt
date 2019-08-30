from __future__ import absolute_import

from subprocess import Popen, PIPE


def __virtual__():
    return "caasp_kubernetes_kubectl"


def kubeconfig_path():
    return __salt__['pillar.get']('paths:kubeconfig')


def kubectl_args(namespace=None, output=None):
    args = {
        'kubeconfig': kubeconfig_path()
    }

    if namespace is not None:
        args['namespace'] = namespace
    if output is not None:
        args['output'] = output

    return list('--%s=%s' % (key, value) for (key, value) in args.items())


def kubectl(command, namespace=None, stdin=None, output=None):
    process = Popen(["kubectl"] + kubectl_args(namespace, output) + command.split(" "), stdin=PIPE, stdout=PIPE, stderr=PIPE)
    stdout, stderr = process.communicate(stdin)
    return process.returncode, stdout, stderr
