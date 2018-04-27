from __future__ import absolute_import

import subprocess

# note: do not import caasp modules other than caasp_log
from caasp_log import abort, debug, error, info, warn

# minimum number of etcd masters we recommend
MIN_RECOMMENDED_MEMBER_COUNT = 3

# port where etcd listens for clients
ETCD_CLIENT_PORT = 2379


def __virtual__():
    return "caasp_etcd"


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


def get_cluster_size(**kwargs):
    '''
    Determines the optimal/desired (but possible) etcd cluster size

    Determines the desired number of cluster members, defaulting to
    the value supplied in the etcd:masters pillar, falling back to
    match the number nodes with the kube-master role, and if this is
    less than 3, it will bump it to 3 (or the number of nodes
    available if the number of nodes is less than 3).

    Optional arguments:

      * `masters`: list of current kubernetes masters
      * `minions`: list of current kubernetes minions

    '''
    member_count = __salt__['pillar.get']('etcd:masters', None)

    masters = __salt__['caasp_nodes.get_from_args_or_with_expr'](
        'masters', kwargs, 'G@roles:kube-master')
    minions = __salt__['caasp_nodes.get_from_args_or_with_expr'](
        'minions', kwargs, 'G@roles:kube-minion')

    if not member_count:
        # A value has not been set in the pillar, calculate a "good" number
        # for the user.
        num_masters = len(masters)

        member_count = _optimal_etcd_number(num_masters)
        if member_count < MIN_RECOMMENDED_MEMBER_COUNT:
            # Attempt to increase the number of etcd master to 3,
            # however, if we don't have 3 nodes in total,
            # then match the number of nodes we have.
            increased_member_count = len(masters) + len(minions)
            increased_member_count = min(
                MIN_RECOMMENDED_MEMBER_COUNT, increased_member_count)

            # ... but make sure we are using an odd number
            # (otherwise we could have some leader election problems)
            member_count = _optimal_etcd_number(increased_member_count)

            warn("etcd member count too low (%d), increasing to %d",
                 num_masters, increased_member_count)

            # TODO: go deeper and look for candidates in nodes with
            #       no role (as get_replacement_for_member() does)
    else:
        # A value has been set in the pillar, respect the users choice
        # even it's not a "good" number.
        member_count = int(member_count)

        if member_count < MIN_RECOMMENDED_MEMBER_COUNT:
            warn("etcd member count too low (%d), consider increasing "
                 "to %d", member_count, MIN_RECOMMENDED_MEMBER_COUNT)

    member_count = max(1, member_count)
    debug("using member count = %d", member_count)
    return member_count


def get_additional_etcd_members(num_wanted=None, **kwargs):
    '''
    Taking into account

      1) the current number of etcd members, and
      2) the number of etcd nodes we should be running in the
         cluster (obtained with `get_cluster_size()`)

    get a list of additional nodes (IDs) that should run `etcd` too.

    Optional arguments:

      * `etcd_members`: list of current etcd members
      * `excluded`: list of nodes to exclude
    '''
    excluded = kwargs.get('excluded', [])

    current_etcd_members = __salt__['caasp_nodes.get_from_args_or_with_expr'](
        'etcd_members', kwargs, 'G@roles:etcd')
    num_current_etcd_members = len(current_etcd_members)

    # the number of etcd masters that should be in the cluster
    num_wanted_etcd_members = num_wanted or get_cluster_size(**kwargs)
    #... and the number we are missing
    num_additional_etcd_members = num_wanted_etcd_members - num_current_etcd_members

    if num_additional_etcd_members <= 0:
        debug('get_additional_etcd_members: we dont need more etcd members')
        return []

    debug('get_additional_etcd_members: curr:%d wanted:%d -> %d missing',
          num_current_etcd_members, num_wanted_etcd_members, num_additional_etcd_members)

    # Get a list of `num_additional_etcd_members` nodes that could be used
    # for running etcd. A valid node is a node that:
    #
    #   1) is not the `admin` or `ca`
    #   2) has no `etcd` role (bootstrapped or not)
    #   2) is not being removed/added/updated
    #   3) (in preference order, first for non bootstrapped nodes)
    #       1) has no role assigned
    #       2) is a master
    #       3) is a minion
    #
    new_etcd_members = __salt__['caasp_nodes.get_with_prio_for_role'](
        num_additional_etcd_members, 'etcd',
        excluded=current_etcd_members + excluded)

    if len(new_etcd_members) < num_additional_etcd_members:
        error('get_additional_etcd_members: cannot satisfy the %s members missing',
              num_additional_etcd_members)

    return new_etcd_members


def get_endpoints(with_id=False, skip_this=False, skip_removed=False, port=ETCD_CLIENT_PORT, sep=','):
    '''
    Build a comma-separated list of etcd endpoints

    It will skip

      * current node, when `skip_this=True`
      * nodes with G@node_removal_in_progress=true, when `skip_removed=True`

    '''
    expr = 'G@roles:etcd'
    if skip_removed:
        expr += ' and not G@node_removal_in_progress:true'

    etcd_members_lst = []
    for (node_id, name) in __salt__['caasp_grains.get'](expr).items():
        if skip_this and name == __salt__['caasp_net.get_nodename']():
            continue
        member_endpoint = 'https://{}:{}'.format(name, port)
        if with_id:
            member_endpoint = "{}={}".format(node_id, member_endpoint)
        etcd_members_lst.append(member_endpoint)

    if len(etcd_members_lst) == 0:
        error('no etcd members available!!')
        raise NoEtcdServersException()

    etcd_members_lst.sort()
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


def get_member_id(nodename=None):
    '''
    Return the member ID (different from the node ID) for
    a etcd member of the cluster.

    Arguments:

    * `nodename`: (optional) the nodename for the member we
                  want the ID for. if no name is provided (or empty),
                  the local node will be used.
    '''
    command = ["etcdctl"] + get_etcdctl_args() + ["member", "list"]

    target_nodename = nodename or __salt__['caasp_net.get_nodename']()

    debug("getting etcd member ID with: %s", command)
    try:
        target_url = 'https://{}:{}'.format(target_nodename, ETCD_CLIENT_PORT)
        members_output = subprocess.check_output(command)
        for member_line in members_output.splitlines():
            if target_url in member_line:
                return member_line.split(':')[0]

    except Exception as e:
        error('cannot get member ID for "%s": %s', e, target_nodename)
        error('output: %s', members_output)

    return ''
