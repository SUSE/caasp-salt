from __future__ import absolute_import
import logging


LOG = logging.getLogger(__name__)
DESIRED_MEMBER_COUNT = 3


def __virtual__():
    return "caasp_etcd"

def get_cluster_size():
    """
    Determines the etcd discovery cluster size

    Determines the desired number of cluster members, defaulting to
    the value supplied in the etcd:masters pillar, falling back to
    match the number nodes with the kube-master role, and if this is
    less than 3, it will bump it to 3 (or the number of nodes
    available if the number of nodes is less than 3).
    """
    member_count = __pillar__["etcd"]["masters"]

    if member_count is not None:
        # A value has been set in the pillar, respect the users choice
        # even it's not a "good" number.
        member_count = int(member_count)

        if member_count < DESIRED_MEMBER_COUNT:
            LOG.warning("etcd member count too low (%d), consider increasing "
                        "to %d", member_count, DESIRED_MEMBER_COUNT)

            return member_count

    else:
        # A value has not been set in the pillar, calculate a "good" number
        # for the user.
        member_count = len(__salt__['mine.get'](
            'roles:kube-master', 'caasp_fqdn', expr_form='grain').values())

        if member_count >= DESIRED_MEMBER_COUNT:
            # We have enough members, use this count.
            return member_count
        else:
            # Attempt to increase the member count to 3, however, if we don't
            # have 3 nodes in total, then match the number of nodes we have.
            increased_member_count = len(__salt__['mine.get'](
                'roles:kube-*', 'caasp_fqdn', expr_form='grain').values())
            increased_member_count = min(
                DESIRED_MEMBER_COUNT, increased_member_count)

            LOG.warning("etcd member count too low (%d), increasing to %d",
                        member_count, increased_member_count)

            return increased_member_count
