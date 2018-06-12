from __future__ import absolute_import

from salt.exceptions import CommandExecutionError

# the pillar where we store the kubeconfig path
PILLAR_KUBECONFIG_PATH = 'paths:kubeconfig'

# default tiemout for requests to the API
DEFAULT_REQUEST_TIMEOUT = '1m'

# default namespace
DEFAULT_NAMESPACE = 'kube-system'

# default number of trials for kubectl
DEFAULT_ATTEMPTS = 10

# ... and the interval between them
DEFAULT_ATTEMPTS_INTERVAL = 2


NODENAME_GRAIN = 'nodename'


def run(name,
        kubeconfig=None,
        namespace=DEFAULT_NAMESPACE,
        timeout=DEFAULT_REQUEST_TIMEOUT,
        retry={},
        **kwargs):
    '''
    Run a kubectl command

    kubeconfig
        A path to the kubeconfig file

    namespace
        Name of the namespace.

    timeout
        Request timeout.

    .. code-block:: yaml

        remove-old-find-dex-role:
          caasp_kubectl.run:
            - name:    delete role find-dex -n kube-system
            - onlyif:  kubectl --request-timeout=1m get role find-dex -n kube-system
            - require:
              - sls:   kubectl-config
    '''
    retry_ = {'attempts': DEFAULT_ATTEMPTS,
              'interval': DEFAULT_ATTEMPTS_INTERVAL,
              'until': None}
    retry_.update(retry)

    args = []

    if not kubeconfig:
        kubeconfig = __salt__['caasp_pillar.get'](PILLAR_KUBECONFIG_PATH, None)

    if kubeconfig:
        args.append('--kubeconfig {}'.format(kubeconfig))
    else:
        __salt__['caasp_log.error']('no kubeconfig for running kubectl')

    if namespace:
        args.append('--namespace {}'.format(namespace))

    if timeout:
        args.append('--request-timeout {}'.format(timeout))

    cmd = "kubectl {} {}".format(' '.join(args), name)

    __salt__['caasp_log.debug']('running kubectl command: {}'.format(cmd))
    return __states__['caasp_cmd.run'](name=cmd,
                                       retry=retry_,
                                       **kwargs)


def apply(name,
          user='root',
          group='root',
          mode='0600',
          dir_mode='0700',
          **kwargs):
    '''
    Copy the jinja templates from `directory` or `file`
    to `name`, and then apply as kubectl manifests.

    name
        Copy destination.

    directory
        Name of the directory to copy to `name`.

    file
        Name of the file to copy to `name`.

    user
        The user to own the copied file(s).

    group
        The group to own the copied file(s).

    mode
        The permissions mode to set files copied.

    makedirs
        When copying a file, create all the necessary
        directories (defaults to True)

    '''
    apply_file = kwargs.pop('file', None)
    apply_directory = kwargs.pop('directory', None)

    common_kwargs = {
        'name': name,
        'user': user,
        'group': group,
        'dir_mode': dir_mode,
        'template': kwargs.pop('template', 'jinja'),
        'defaults': kwargs.pop('defaults', {})
    }

    if apply_directory:
        ret = __states__['file.recurse'](source=apply_directory,
                                         file_mode=mode,
                                         clean=True,
                                         **common_kwargs)
    elif apply_file:
        ret = __states__['file.managed'](source=apply_file,
                                         mode=mode,
                                         makedirs=kwargs.pop('makedirs', True),
                                         **common_kwargs)
    else:
        __salt__['caasp_log.abort']('dont know what to apply')

    if not ret['result']:
        return {'name': name,
                'changes': ret['changes'],
                'result': False,
                'comment': "Manifests copy to {} failed: {}".format(name, ret['comment'])}

    # the `kubectl apply -f` must `watch` the manifest(s) we are creating
    watch = ['file.{}'.format(name)] + kwargs.pop('watch', [])

    return run(name='apply -f {}'.format(name),
               watch=watch,
               **kwargs)


def taint(name,
          node=None,
          overwrite=False,
          **kwargs):
    '''
    Taint a node.

    name
        Taint to apply.

    node
        Node name.

    overwrite
        Overwrite the taint.
    '''
    if not node:
        node = __salt__['grains.get'](NODENAME_GRAIN)

    cmd_args_lst = []
    if overwrite:
        cmd_args_lst.append('--overwrite')

    cmd_args = ' '.join(cmd_args_lst)
    cmd = 'taint node {cmd_args} {node} {name}'.format(**locals())
    return run(name=cmd, **kwargs)


def label(name,
          node=None,
          overwrite=False,
          **kwargs):
    '''
    Label a node.

    name
        Label to apply.

    node
        Node name.

    overwrite
        Overwrite the label.
    '''
    if not node:
        node = __salt__['grains.get'](NODENAME_GRAIN)

    cmd_args_lst = []
    if overwrite:
        cmd_args_lst.append('--overwrite')

    cmd_args = ' '.join(cmd_args_lst)
    cmd = 'label node {cmd_args} {node} {name}'.format(**locals())
    return run(name=cmd, **kwargs)


def check_deployment(name, **kwargs):
    '''
    Check a deployment is fully deployed/available.

    Accepts the same list of arguments as `run`.
    '''
    def _get_replicas(description):
        template = '{{' + description + '}}'
        cmd = "get deployment {} --template '{}'".format(name, template)
        ret = run(name=cmd, **kwargs)
        if not ret['result']:
            raise CommandExecutionError(
                'Could not get "{}" with kubectl'.format(description),
                info={'errors': [{'cmd': cmd}, ret['comment']]})

        try:
            stdout = ret['changes']['stdout']
            __salt__['caasp_log.debug']('{}{} = {}'.format(name, description, stdout))
            return int(stdout)
        except ValueError as e:
            # sometimes `kubectl` can return `<no value>`
            __salt__['caasp_log.error'](
                'could not parse "{}" stdout "{}": {}'.format(cmd, stdout, e))
            return None

    __salt__['caasp_log.debug']('checking status of deployment {}'.format(name))
    desired = _get_replicas('.spec.replicas')
    ready = _get_replicas('.status.readyReplicas')
    avail = _get_replicas('.status.availableReplicas')

    if all([desired, ready, avail]) and ready >= desired and avail >= desired:
        result = True
        comment = '{} successfully deployed: '.format(name)
    else:
        result = False
        comment = '{} is currently not deployed: '.format(name)

    comment += 'desired={}, ready={}, avail={}'.format(desired, ready, avail)

    return {'name': name,
            'changes': {},
            'result': result,
            'comment': comment}


def wait_for_deployment(name, retry={}, **kwargs):
    '''
    Wait until a deployment is fully deployed.

    In addition to the arguments accepted by `run`:

    retry
        This allows you to provide `attempts` and `interval`, what will retry the command as much
        ``attempts`` times, separated by `interval` seconds. If 'until' is provided,
        verify we must not try again after running the command successfully
        by runing the `until` condition.

    '''
    _retry = {'attempts': DEFAULT_ATTEMPTS,
              'interval': DEFAULT_ATTEMPTS_INTERVAL,
              'until': None}
    _retry.update(retry)

    __salt__['caasp_log.debug']('waiting for deployment {}'.format(name))
    return __states__['caasp_retriable.retry'](name=name,
                                               target='caasp_kubectl.check_deployment',
                                               retry=_retry,
                                               **kwargs)
