from __future__ import absolute_import
import logging


LOG = logging.getLogger(__name__)


def __virtual__():
    return "etcd_discovery_helpers"


def get_cluster_size():
    """
    Determines the etcd discovery cluster size

    Determines the desired number of cluster members, defaulting to
    the value supplied in the etcd:masters pillar, falling back to
    match the number nodes with the kube-master role, and if this is
    less than 3, it will bump it to 3.
    """
    member_count = __pillar__["etcd"]["masters"]

    if member_count is not None:
        # A value has been set in the pillar, respect the users choice
        # even it's not a "good" number.
        member_count = int(member_count)

        if member_count < 3:
            LOG.warning("etcd member count too low (%d), consider increasing "
                        "to 3", member_count)

    else:
        # A value has not been set in the pillar, calculate a "good" number
        # for the user.
        member_count = len(__salt__['mine.get'](
            'roles:kube-master', 'fqdn', expr_form='grain').values())

        if member_count < 3:
            LOG.warning("etcd member count too low (%d), increasing to 3",
                        member_count)
            member_count = 3

    return member_count
