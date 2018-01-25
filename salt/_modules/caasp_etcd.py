from __future__ import absolute_import

import logging

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


def _get_grain_on_master(expr, grain=_GRAIN_NAME, type='grain'):
    return __salt__['saltutil.runner']('mine.get',
                                       tgt=expr,
                                       fun=grain, tgt_type=type)


def _get_num_kube(expr):
    """
    Get the number of kubernetes nodes that in the cluster that match "expr"
    """
    log.debug("Finding nodes that match '%s' in the cluster", expr)
    nodes = __salt__['mine.get'](expr, _GRAIN_NAME, expr_form='grain').values()
    # 'mine.get' is not available in the master, so it will return nothing
    # in that case, we can try again with saltutil.runner... uh?
    if not nodes:
        log.debug("... using 'saltutil.runner' for getting the '%s' nodes", expr)
        nodes = _get_grain_on_master(expr).values()
    return len(nodes)


def get_cluster_size():
    """
    Determines the optimal/desired (but possible) etcd cluster size

    Determines the desired number of cluster members, defaulting to
    the value supplied in the etcd:masters pillar, falling back to
    match the number nodes with the kube-master role, and if this is
    less than 3, it will bump it to 3 (or the number of nodes
    available if the number of nodes is less than 3).
    """
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

            log.warning("etcd member count too low (%d), increasing to %d",
                        num_masters, increased_member_count)
    else:
        # A value has been set in the pillar, respect the users choice
        # even it's not a "good" number.
        member_count = int(member_count)

        if member_count < MIN_RECOMMENDED_MEMBER_COUNT:
            log.warning("etcd member count too low (%d), consider increasing "
                        "to %d", member_count, MIN_RECOMMENDED_MEMBER_COUNT)

    member_count = max(1, member_count)
    log.debug("using member count = %d", member_count)
    return member_count


def get_additional_etcd_members():
    '''
    Get a list of nodes that are not running etcd members
    and they should.
    '''
    if __opts__['__role'] != 'master':
        log.error(
            'get_additional_etcd_members should only be called in the Salt master', expr)
        raise OnlyOnMasterException()

    # machine IDs in the cluster that are currently etcd servers
    current_etcd_members = _get_grain_on_master(
        'G@roles:etcd', type='compound').keys()
    num_current_etcd_members = len(current_etcd_members)

    # the number of etcd masters that should be in the cluster
    num_wanted_etcd_members = get_cluster_size()
    #... and the number we are missing
    num_additional_etcd_members = num_wanted_etcd_members - num_current_etcd_members
    log.debug(
        'get_additional_etcd_members: curr:{} wanted:{} -> {} missing'.format(num_current_etcd_members, num_wanted_etcd_members, num_additional_etcd_members))

    new_etcd_members = []

    if num_additional_etcd_members > 0:

        masters_no_etcd = _get_grain_on_master(
            'G@roles:kube-master and not G@roles:etcd', type='compound').keys()

        # get k8s masters until we complete the etcd cluster
        masters_and_etcd = masters_no_etcd[:num_additional_etcd_members]
        new_etcd_members = new_etcd_members + masters_and_etcd
        num_additional_etcd_members = num_additional_etcd_members - \
            len(masters_and_etcd)
        log.debug(
            'get_additional_etcd_members: taking {} masters -> {} missing'.format(len(masters_and_etcd), num_additional_etcd_members))

        # if we have run out of k8s masters and we do not have
        # enough etcd members, go for the k8s workers too...
        if num_additional_etcd_members > 0:
            workers_no_etcd = _get_grain_on_master(
                'G@roles:kube-minion and not G@roles:etcd', type='compound').keys()

            workers_and_etcd = workers_no_etcd[:num_additional_etcd_members]
            new_etcd_members = new_etcd_members + workers_and_etcd
            num_additional_etcd_members = num_additional_etcd_members - \
                len(workers_and_etcd)
            log.debug(
                'get_additional_etcd_members: taking {} minions -> {} missing'.format(len(workers_and_etcd), num_additional_etcd_members))

            # TODO: if num_additional_etcd_members is still >0,
            #       fail/raise/message/something...
            if num_additional_etcd_members > 0:
                log.error(
                    'get_additional_etcd_members: cannot satisfy the {} members missing'.format(num_additional_etcd_members))

    return new_etcd_members


def get_endpoints(skip_this=False, etcd_members=[]):
    """
    Build a comma-separated list of etcd endpoints
    """
    this_name = __salt__['grains.get'](_GRAIN_NAME)

    # build the list of etcd masters
    if len(etcd_members) == 0:
        etcd_members = __salt__["mine.get"](
            "G@roles:etcd", _GRAIN_NAME, expr_form="compound").values()

    etcd_members_urls = []
    for name in etcd_members:
        if skip_this and name == this_name:
            continue
        url = "https://{}:{}".format(name, ETCD_CLIENT_PORT)
        etcd_members_urls.append(url)

    if len(etcd_members) == 0:
        log.error("no etcd members available!!")
        raise NoEtcdServersException()

    return ",".join(etcd_members_urls)
