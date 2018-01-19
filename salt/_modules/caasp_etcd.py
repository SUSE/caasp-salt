from __future__ import absolute_import

import logging
import subprocess

log = logging.getLogger(__name__)

# minimum number of etcd masters we recommend
MIN_RECOMMENDED_MEMBER_COUNT = 3

# port where etcd listens for clients
ETCD_CLIENT_PORT = 2379


def __virtual__():
    return "caasp_etcd"


# Grain used for getting nodes
_GRAIN_NAME = 'nodename'


class OnlyOnMasterException(Exception):
    pass


class NoEtcdServersException(Exception):
    pass


def _optimal_etcd_number(num_nodes):
    if num_nodes >= 7:
        return 7
    elif num_nodes >= 5:
        return 5
    elif num_nodes >= 3:
        return 3
    else:
        return 1


def _get_grain(expr, grain=_GRAIN_NAME, type='compound'):
    if __opts__['__role'] == 'master':
        # 'mine.get' is not available in the master: it returns nothing
        # in that case, we should use "saltutil.runner"... uh?
        return __salt__['saltutil.runner']('mine.get',
                                           tgt=expr,
                                           fun=grain, tgt_type=type)
    else:
        return __salt__['mine.get'](expr, grain, expr_form=type)


def _get_this_name():
    return __salt__['grains.get'](_GRAIN_NAME)


def _get_num_kube(expr):
    '''
    Get the number of kubernetes nodes that in the cluster that match "expr"
    '''
    log.debug("CaaS: finding nodes that match '%s' in the cluster", expr)
    return len(_get_grain(expr, type='grain').values())


def get_cluster_size():
    '''
    Determines the optimal/desired (but possible) etcd cluster size

    Determines the desired number of cluster members, defaulting to
    the value supplied in the etcd:masters pillar, falling back to
    match the number nodes with the kube-master role, and if this is
    less than 3, it will bump it to 3 (or the number of nodes
    available if the number of nodes is less than 3).
    '''
    member_count = __salt__['pillar.get']('etcd:masters', None)

    if not member_count:
        # A value has not been set in the pillar, calculate a "good" number
        # for the user.
        num_masters = _get_num_kube("roles:kube-master")

        member_count = _optimal_etcd_number(num_masters)
        if member_count < MIN_RECOMMENDED_MEMBER_COUNT:
            # Attempt to increase the number of etcd master to 3,
            # however, if we don't have 3 nodes in total,
            # then match the number of nodes we have.
            increased_member_count = _get_num_kube("roles:kube-*")
            increased_member_count = min(
                MIN_RECOMMENDED_MEMBER_COUNT, increased_member_count)

            # ... but make sure we are using an odd number
            # (otherwise we could have some leader election problems)
            member_count = _optimal_etcd_number(increased_member_count)

            log.warning("CaaS: etcd member count too low (%d), increasing to %d",
                        num_masters, increased_member_count)

            # TODO: go deeper and look for candidates in nodes with
            #       no role (as get_replacement_for_member() does)
    else:
        # A value has been set in the pillar, respect the users choice
        # even it's not a "good" number.
        member_count = int(member_count)

        if member_count < MIN_RECOMMENDED_MEMBER_COUNT:
            log.warning("CaaS: etcd member count too low (%d), consider increasing "
                        "to %d", member_count, MIN_RECOMMENDED_MEMBER_COUNT)

    member_count = max(1, member_count)
    log.debug("CaaS: using member count = %d", member_count)
    return member_count


def get_replacement_for_member():
    '''
    Get a node that can replace a etcd member

    A valid replacement is a node that:

      1) is not 'admin' or 'ca'
      2) is not an etcd member
      2) is not going to be removed/added/updated
      3) (in preference order)
          1) has no role assigned
          2) is a master
          3) is a minion

    Returns '' if no replacement can be found.
    '''

    prio_roles = ['not G@roles:kube-(master|minion)',
                  'G@roles:kube-master',
                  'G@roles:kube-minion']
    for role in prio_roles:
        expr = ''
        expr += 'not G@roles:etcd'
        expr += ' and not G@roles:admin and not G@roles:ca'
        expr += ' and not P@.*_in_progress:true'
        expr += ' and {}'.format(role)

        log.debug('CaaS: trying to find an etcd replacement with %s', expr)
        ids = _get_grain(expr).keys()
        if len(ids) > 0:
            log.debug('CaaS: ... candidates for replacement: %s', str(ids))
            return ids[0]
        else:
            log.debug('CaaS: ... no candidates found')

    log.error('CaaS: no etcd replacement could be found')
    return ''


def get_additional_etcd_members():
    '''
    Taking into account

      1) the current number of etcd members, and
      2) the number of etcd nodes we should be running in the
         cluster (obtained with `get_cluster_size()`)

    get a list of additional nodes (IDs) that should run `etcd` too.
    '''
    # machine IDs in the cluster that are currently etcd servers
    current_etcd_members = _get_grain('G@roles:etcd').keys()
    num_current_etcd_members = len(current_etcd_members)

    # the number of etcd masters that should be in the cluster
    num_wanted_etcd_members = get_cluster_size()
    #... and the number we are missing
    num_additional_etcd_members = num_wanted_etcd_members - num_current_etcd_members
    log.debug(
        'get_additional_etcd_members: curr:{} wanted:{} -> {} missing'.format(num_current_etcd_members, num_wanted_etcd_members, num_additional_etcd_members))

    new_etcd_members = []

    if num_additional_etcd_members > 0:

        masters_no_etcd = _get_grain(
            'G@roles:kube-master and not G@roles:etcd').keys()

        # get k8s masters until we complete the etcd cluster
        masters_and_etcd = masters_no_etcd[:num_additional_etcd_members]
        new_etcd_members = new_etcd_members + masters_and_etcd
        num_additional_etcd_members = num_additional_etcd_members - \
            len(masters_and_etcd)
        log.debug(
            'CaaS: get_additional_etcd_members: taking {} masters -> {} missing'.format(len(masters_and_etcd), num_additional_etcd_members))

        # if we have run out of k8s masters and we do not have
        # enough etcd members, go for the k8s workers too...
        if num_additional_etcd_members > 0:
            workers_no_etcd = _get_grain(
                'G@roles:kube-minion and not G@roles:etcd').keys()

            workers_and_etcd = workers_no_etcd[:num_additional_etcd_members]
            new_etcd_members = new_etcd_members + workers_and_etcd
            num_additional_etcd_members = num_additional_etcd_members - \
                len(workers_and_etcd)
            log.debug(
                'CaaS: get_additional_etcd_members: taking {} minions -> {} missing'.format(len(workers_and_etcd), num_additional_etcd_members))

            # TODO: if num_additional_etcd_members is still >0,
            #       fail/raise/message/something...
            if num_additional_etcd_members > 0:
                log.error(
                    'CaaS: get_additional_etcd_members: cannot satisfy the {} members missing'.format(num_additional_etcd_members))

            # TODO: go deeper and look for candidates in nodes with
            #       no role (as get_replacement_for_member() does)

    return new_etcd_members


def get_endpoints(with_id=False, skip_this=False, skip_removed=False, port=ETCD_CLIENT_PORT, sep=','):
    '''
    Build a comma-separated list of etcd endpoints

    It will skip

      * current node, when `skip_this=True`
      * nodes with G@removal_in_progress=true, when `skip_removed=True`

    '''
    expr = 'G@roles:etcd'
    if skip_removed:
        expr += ' and not G@removal_in_progress:true'

    etcd_members_lst = []
    for (node_id, name) in _get_grain(expr).items():
        if skip_this and name == _get_this_name():
            continue
        member_endpoint = 'https://{}:{}'.format(name, port)
        if with_id:
            member_endpoint = "{}={}".format(node_id, member_endpoint)
        etcd_members_lst.append(member_endpoint)

    if len(etcd_members_lst) == 0:
        log.error('CaaS: no etcd members available!!')
        raise NoEtcdServersException()

    return sep.join(etcd_members_lst)


def get_etcdctl_args(skip_this=False):
    '''
    Build the list of args for 'etcdctl'
    '''
    etcdctl_args = []
    etcdctl_args += ["--ca-file", __salt__['pillar.get']('ssl:ca_file')]
    etcdctl_args += ["--key-file", __salt__['pillar.get']('ssl:key_file')]
    etcdctl_args += ["--cert-file", __salt__['pillar.get']('ssl:crt_file')]

    etcd_members_lst = get_endpoints(skip_this=skip_this)

    return etcdctl_args + ["--endpoints", etcd_members_lst]


def get_etcdctl_args_str(**kwargs):
    '''
    Get the 'etcdctl' arguments (as a string)
    '''
    return " ".join(get_etcdctl_args(**kwargs))


def get_member_id():
    '''
    Return the member ID (different from the node ID) for
    this etcd member of the cluster.
    '''
    command = ["etcdctl"] + get_etcdctl_args() + ["member", "list"]

    log.debug("CaaS: getting etcd member ID with: %s", command)
    try:
        this_url = 'https://{}:{}'.format(_get_this_name(), ETCD_CLIENT_PORT)
        members_output = subprocess.check_output(command)
        for member_line in members_output.splitlines():
            if this_url in member_line:
                return member_line.split(':')[0]

    except Exception as e:
        log.error("CaaS: cannot get member ID: %s", e)
        log.error("CaaS: output: %s", members_output)

    return ''
