from __future__ import absolute_import

import re
import subprocess

try:
    from urllib.parse import urlparse
except ImportError:
    from urlparse import urlparse

# note: do not import caasp modules other than caasp_log
from caasp_log import debug, error, warn

# minimum number of etcd members we recommend
MIN_RECOMMENDED_MEMBER_COUNT = 3

# port where etcd listens for clients
ETCD_CLIENT_PORT = 2379

# default etcd peer port
ETCD_PEER_PORT = 2380


def __virtual__():
    return "caasp_etcd"


class NoEtcdServersException(Exception):
    pass


def api_version():
    return __salt__['pillar.get']('etcd_version', 'etcd2')


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
            # Attempt to increase the number of etcd members to 3,
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


def get_surplus_etcd_members(num_wanted=None, targets=[], **kwargs):
    '''
    Taking into account

      1) the current number of etcd members, and
      2) the number of etcd nodes we should be running in the
         cluster (obtained with `get_cluster_size()`)
      3) the `targets` to be removed overall

    get a list of surplus nodes (IDs) that should not run `etcd`, not included
    in `targets`
    '''
    excluded = kwargs.get('excluded', [])

    current_etcd_members = __salt__['caasp_nodes.get_from_args_or_with_expr'](
        'etcd_members', kwargs, 'G@roles:etcd')
    num_current_etcd_members = len(current_etcd_members)

    targets_and_etcd_members = set(targets).intersection(set(current_etcd_members))

    # the number of etcd members that should be in the cluster
    num_wanted_etcd_members = num_wanted or get_cluster_size(**kwargs)
    # ... and the number we are passing
    num_surplus_etcd_members = num_current_etcd_members - num_wanted_etcd_members

    if num_surplus_etcd_members <= 0:
        debug('get_surplus_etcd_members: we dont need to remove etcd members')
        return []

    debug('get_surplus_etcd_members: curr:%d wanted:%d -> %d surplus',
          num_current_etcd_members, num_wanted_etcd_members, num_surplus_etcd_members)

    result = __salt__['caasp_nodes.get_with_prio_for_role'](
        num_surplus_etcd_members, 'etcd-removal',
        unassigned=False,
        excluded=targets + excluded)

    return result[:-len(targets_and_etcd_members)]


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

    # the number of etcd members that should be in the cluster
    num_wanted_etcd_members = num_wanted or get_cluster_size(**kwargs)
    # ... and the number we are missing
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
        unassigned=False,
        excluded=current_etcd_members + excluded)

    if len(new_etcd_members) < num_additional_etcd_members:
        error('get_additional_etcd_members: cannot satisfy the %s members missing',
              num_additional_etcd_members)

    return new_etcd_members


def get_endpoints_expr(skip_this=False, skip_removed=False, only_bootstrapped=True):
    '''
    Returns the salt matcher to target the expected minions

    Arguments:

    * `skip_this`: Skip this machine from being included in the results.
    * `skip_removed`: Skip the machines that are currently in the process of being removed.
    * `only_boostrapped`: Only include machines that have been successfully bootstrapped in the past.
    '''
    expr = ['G@roles:etcd']

    if skip_this:
        expr.append('not ' + __salt__['grains.get']('id'))
    if skip_removed:
        expr.append('not G@node_removal_in_progress:true')
    if only_bootstrapped and not __salt__['caasp_nodes.is_first_bootstrap']():
        expr.append('( G@bootstrap_complete:true or ' + __salt__['grains.get']('id') + ' )')

    return ' and '.join(expr)


def get_endpoints_raw(with_id=False, skip_this=False, skip_removed=False, only_bootstrapped=True, port=ETCD_CLIENT_PORT):
    '''
    Build a list of cached etcd endpoints as seen by salt.

    Arguments:

    * `with_id`: Return the nodename of each endpoint along with the endpoint itself (form `nodename=endpoint`).
    * `skip_this`: Skip this machine from being included in the result.
    * `skip_removed`: Skip the machines that are currently in the process of being removed.
    * `only_boostrapped`: Only include machines that have been successfully bootstrapped in the past.
    * `port`: The port to be used in the endpoints.
    '''
    expr = get_endpoints_expr(skip_this, skip_removed, only_bootstrapped)
    etcd_members_lst = []
    for (node_id, name) in __salt__['caasp_grains.get'](expr).items():
        member_endpoint = 'https://{}:{}'.format(name, port)
        if with_id:
            member_endpoint = "{}={}".format(node_id, member_endpoint)
        etcd_members_lst.append(member_endpoint)

    if len(etcd_members_lst) == 0:
        error('no etcd members available!!')
        raise NoEtcdServersException()

    etcd_members_lst.sort()
    return etcd_members_lst


def get_endpoints(with_id=False, skip_this=False, skip_removed=False, only_bootstrapped=True, port=ETCD_CLIENT_PORT, sep=','):
    '''
    Retrieve the list of cached etcd endpoints as seen by salt as a string, separated by `sep`.

    Arguments:

    * `with_id`: Return the nodename of each endpoint along with the endpoint itself (form `nodename=endpoint`).
    * `skip_this`: Skip this machine from being included in the result.
    * `skip_removed`: Skip the machines that are currently in the process of being removed.
    * `only_boostrapped`: Only include machines that have been successfully bootstrapped in the past.
    * `port`: The port to be used in the endpoints.
    * `sep`: The separator to be used to convert the list in a string.
    '''
    return sep.join(get_endpoints_raw(with_id, skip_this, skip_removed, only_bootstrapped, port))


def get_current_endpoints_raw(with_id=False, port=ETCD_CLIENT_PORT):
    '''
    Build a list of current etcd endpoints (as currently seen by the etcd cluster).

    Arguments:

    * `with_id`: (optional) Return the nodename of each endpoint along with the endpoint itself (form `nodename=endpoint`).
    * `port`: (optional) The port to be used for the endpoints.

    This requires etcd to be responding. Otherwise, `subprocess.CalledProcessError` will be raised.
    '''
    etcd_members_lst = []
    for member in member_list()['active']:
        member_endpoint = urlparse(member['peer_urls'])
        member_endpoint = member_endpoint._replace(netloc=member_endpoint.netloc.replace(str(member_endpoint.port), str(port)))
        member_endpoint = member_endpoint.geturl()
        if with_id:
            member_endpoint = "{}={}".format(member['name'], member_endpoint)
        etcd_members_lst.append(member_endpoint)

    etcd_members_lst.sort()
    return etcd_members_lst


def this_endpoint(with_id=True, port=ETCD_CLIENT_PORT):
    '''
    Retrieve this endpoint as a string.

    Arguments:

    * `with_id`: (optional) Whether to include the node id in the endpoint (not the member id).
    * `port`: (optional) The port to be used in this endpoint.
    '''
    endpoint = 'https://{}:{}'.format(__salt__['grains.get']('nodename'), port)
    if with_id:
        return '{}={}'.format(__salt__['grains.get']('id'), endpoint)

    return endpoint


def get_current_endpoints(with_id=False, port=ETCD_CLIENT_PORT, sep=','):
    '''
    Retrieve the list of current endpoints as seen by the etcd cluster as a string, separated by `sep`.

    This requires etcd to be responding. Otherwise, `subprocess.CalledProcessError` will be raised.
    '''
    return sep.join(get_current_endpoints_raw(with_id, port))


def get_current_endpoints_with_self(port=ETCD_CLIENT_PORT, with_id=True, sep=','):
    '''
    Retrieve the list of current endpoints as seen by the etcd cluster as a string, separated by
    `sep`, also including the local endpoint.

    First, we try to retrieve this list from the live etcd cluster. This allows us to easily write
    the real configuration for other etcd instances if we are growing the cluster or modifying it,
    since `etcd` is very sensitive with endpoints, and they should match what etcd has in its
    cluster information at the moment. This is usually the case when we are growing/shrinking the
    cluster.

    If we cannot retrieve the endpoints from the etcd cluster, we fallback to a salt 'cached'
    result, using grains. Depending on the state of the cluster, this might be used during upgrades,
    for example. It's fine to use our 'cache' in this case, because at that time we don't expect the
    `etcd` cluster to change.

    Arguments:

    * `port`: The port to be used on the endpoints.
    * `with_id`: Whether the endpoints should also include the name of the member (not the member id).
    * `sep`: The separator to use when joining the list of current endpoints into a single string.
    '''
    try:
        current_endpoints = get_current_endpoints_raw(with_id=with_id, port=port)
    except subprocess.CalledProcessError:
        debug('Could not retrieve endpoints from the etcd cluster, falling back to cached results')
        try:
            current_endpoints = get_endpoints_raw(with_id=with_id, skip_this=True, skip_removed=True, only_bootstrapped=True, port=port)
        except NoEtcdServersException:
            # In a 1+1 deployment since we are doing `skip_this` a `NoEtcdServersException` might be raised, in that case we are going
            # to add this endpoint later on here, so don't worry about it.
            current_endpoints = []

    this_endpoint_ = this_endpoint(with_id=with_id, port=port)
    if this_endpoint_ not in current_endpoints:
        current_endpoints.append(this_endpoint_)
        current_endpoints.sort()

    return sep.join(current_endpoints)


def get_etcdctl_args(skip_this=False):
    '''
    Build the list of args for etcdctl.

    This will include all current etcd members endpoints.
    '''
    etcdctl_args = []

    if api_version() == 'etcd2':
        etcdctl_args += ["--ca-file", __salt__['pillar.get']('ssl:ca_file')]
        etcdctl_args += ["--key-file", __salt__['pillar.get']('ssl:key_file')]
        etcdctl_args += ["--cert-file", __salt__['pillar.get']('ssl:crt_file')]
    else:
        etcdctl_args += ["--cacert", __salt__['pillar.get']('ssl:ca_file')]
        etcdctl_args += ["--key", __salt__['pillar.get']('ssl:key_file')]
        etcdctl_args += ["--cert", __salt__['pillar.get']('ssl:crt_file')]

    etcd_members_lst = get_endpoints(skip_this=skip_this)

    return etcdctl_args + ["--endpoints", etcd_members_lst]


def get_etcdctl_args_str(**kwargs):
    '''
    Get the etcdctl arguments (as a string)
    '''
    return " ".join(get_etcdctl_args(**kwargs))


def get_member_id(nodename):
    '''
    Return the member ID (different from the node ID) for an etcd member of the cluster.

    Arguments:

    * `nodename`: (optional) the nodename for the member we
                  want the ID for. if no name is provided (or empty),
                  the local node will be used.
    '''
    members_output = ''
    try:
        target_url = 'https://{}:{}'.format(nodename, ETCD_CLIENT_PORT)
        members_output = etcdctl(["member", "list"])
        for member_line in members_output.splitlines():
            if target_url in member_line:
                return member_line.split(':')[0]

    except Exception as e:
        error('cannot get member ID for "%s": %s', e, nodename)
        error('output: %s', members_output)

    return ''


def is_member_registered(nodename=None, port=ETCD_PEER_PORT):
    '''
    Returns whether the provided `nodename` using `port` is already registered as an etcd member.

    This requires etcd to be responding.
    '''
    target_nodename = nodename or __salt__['caasp_net.get_nodename']()
    target_url = 'https://{}:{}'.format(target_nodename, port)
    member_list_ = member_list()

    for group in member_list_.keys():
        if target_url in map(lambda member: member['peer_urls'], member_list_[group]):
            return True

    return False


def should_register_etcd_member(nodename=None, port=ETCD_CLIENT_PORT):
    '''
    Returns whether a `nodename` with `port` should be registered in etcd or not.

    This is called by machines having the `etcd` role, to find out if they should call to
    `member_add` or not.

    If `nodename` is `None`, the local `nodename` grain will be used.

    The rationale is that we need to add an etcd member only if it's not the first bootstrap
    (no etcd members will be joining a cluster, they'll be creating a new one), the cluster needs
    to be in a healthy state, and the member should not be already registered.
    '''
    return not __salt__['caasp_nodes.is_first_bootstrap']() and healthy() and not is_member_registered(nodename=nodename, port=port)


def healthy():
    '''
    Returns whether the etcd cluster is healthy or not.
    '''
    try:
        if api_version() == 'etcd2':
            etcdctl(['cluster-health'])
        else:
            etcdctl(['endpoint', 'health', '--cluster'])
        return True
    except subprocess.CalledProcessError:
        return False


def member_list():
    '''
    Returns the member list as seen by the etcd cluster.

    The result is a hash with `active` and `unstarted` keys. `active` members are those which
    actually has ever registered against etcd. `unstarted` members are those that have been
    added to `etcd` (by using `member_add`), but did not yet start `etcd` on that machine, so
    `etcd` is aware of it, but it's not yet active.

    This requires etcd to be responding.
    '''
    result = {'active': [], 'unstarted': []}
    etcdctl_output = etcdctl(["member", "list"])
    if api_version() == 'etcd2':
        etcdctl_output_active_matcher = re.compile('([^:]+):\s+name=([^\s]+)\s+peerURLs=([^\s]+)\s+clientURLs=([^\s]+)')
        etcdctl_output_unstarted_matcher = re.compile('([^\[]+)\[unstarted\]:\s+peerURLs=([^\s]+)')
    else:
        etcdctl_output_active_matcher = re.compile('([^,]+), started,\s+([^,]+),\s+([^,]+),\s+([^,]+)')
        etcdctl_output_unstarted_matcher = re.compile('([^,]+), unstarted,[^,]+,([^,]+)')
    for member_line in etcdctl_output.splitlines():
        matches = etcdctl_output_active_matcher.match(member_line)
        if matches:
            matches = matches.groups()
            result['active'].append({'member_id': matches[0], 'name': matches[1], 'peer_urls': matches[2], 'client_urls': matches[3]})
        matches = etcdctl_output_unstarted_matcher.match(member_line)
        if matches:
            matches = matches.groups()
            result['unstarted'].append({'member_id': matches[0], 'peer_urls': matches[1]})

    return result


def member_add(name=None, nodename=None, port=ETCD_PEER_PORT):
    '''
    Adds `nodename` with `port` as an etcd member with name `name`.

    This just raises awareness of a new member coming. etcd needs to be started with the proper
    arguments in order for that member to actually register.

    If `name` is None the local `id` grain of this machine will be used.
    If `nodename` is None the local `nodename` grain of this machine will be used.

    This requires etcd to be responding.
    '''
    this_id = name or __salt__['grains.get']('id')
    nodename_ = nodename or __salt__['caasp_net.get_nodename']()
    aliases = __salt__['caasp_net.get_aliases'](nodename_)
    if any([get_member_id(alias) for alias in aliases]):
        # If this node is already registered in the cluster we pretend it was successfully added.
        return True
    this_peer_url = 'https://{}:{}'.format(nodename_, port)

    debug('CaaS: adding etcd member %s', this_id)
    if api_version() == 'etcd2':
        return etcdctl(['member', 'add', this_id, this_peer_url], skip_this=True)
    else:
        return etcdctl(['member', 'add', this_id, '--peer-urls={}'.format(this_peer_url)], skip_this=True)


def member_remove(nodename):
    '''
    Remove `nodename` as an etcd member.

    If `nodename` is none the local `nodename` grain of this machine will be used to identify the
    member ID of this machine in the etcd cluster.

    This requires etcd to be responding.
    '''
    target_member_id = get_member_id(nodename=nodename)
    if not target_member_id:
        return False

    debug('CaaS: removing etcd member %s', target_member_id)
    return etcdctl(['member', 'remove', target_member_id])


def etcdctl(command, skip_this=False):
    '''
    Execute `command` as an etcdctl command.

    We will pass to etcdctl command the list of all the endpoints we are aware are running `etcd`
    at the time of running this command.

    Arguments:

    * `command`: is a list of arguments to be passed to etcdctl.
    * `skip_this`: do not include this endpoint in the list of endpoints to pass to etcdctl.
    '''
    if api_version() == 'etcd2':
        etcdctl_version = {"ETCDCTL_API": "2"}
    else:
        etcdctl_version = {"ETCDCTL_API": "3"}
    return subprocess.check_output(["etcdctl"] + get_etcdctl_args(skip_this) + command, env=etcdctl_version)
