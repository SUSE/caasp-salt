from __future__ import absolute_import

# note: do not import caasp modules other than caasp_log
from caasp_log import abort, debug, error, info, warn

# minimum number of nodes (per role) we can have after a removal
_MIN_ETCD_MEMBERS_AFTER_REMOVAL = 1
_MIN_MASTERS_AFTER_REMOVAL = 1
_MIN_MINIONS_AFTER_REMOVAL = 1


def _get_prio_etcd(unassigned=False):
    '''
    Get the priorities for choosing new nodes for running
    new etcd members.

    Optional arguments:

      * `unassigned`: consider nodes with no roles assigned
    '''
    res = []

    # etcd nodes that not been bootstrapped yet
    # (ie, the role has been assigned in Velum)
    res.append('G@roles:etcd and not G@bootstrap_complete:true')

    if unassigned:
        # has no role (prefering non-bootstrapped nodes)
        res.append('not P@roles:(kube-master|kube-minion|etcd) and not G@bootstrap_complete:true')
        res.append('not P@roles:(kube-master|kube-minion|etcd)')

    # kubernetes masters (prefering non-bootstrapped nodes)
    res.append('G@roles:kube-master and not G@bootstrap_complete:true')
    res.append('G@roles:kube-master')

    # kuberetes minions (prefering non-bootstrapped nodes)
    res.append('G@roles:kube-minion and not G@bootstrap_complete:true')
    res.append('G@roles:kube-minion')

    return res


def _get_prio_master(unassigned=False):
    '''
    Get the priorities for choosing new nodes for running
    a new kubernetes master.

    Optional arguments:

      * `unassigned`: consider nodes with no roles assigned
    '''
    res = []

    # kubernetes masters that not been bootstrapped yet
    # (ie, the role has been assigned in Velum)
    res.append('G@roles:kube-master and not G@bootstrap_complete:true')

    if unassigned:
        # nodes with no role (preferring non-bootstrapped nodes)
        res.append('not P@roles:(kube-master|kube-minion|etcd) and not G@bootstrap_complete:true')
        res.append('not P@roles:(kube-master|kube-minion|etcd)')

    # etcd-only nodes (preferring non-bootstrapped nodes)
    res.append('G@roles:etcd and not G@roles:kube-master and not G@bootstrap_complete:true')
    res.append('G@roles:etcd and not G@roles:kube-master')
    return res


def _get_prio_minion(unassigned=False):
    '''
    Get the priorities for choosing new nodes for running
    a new kubernetes minion.

    Optional arguments:

      * `unassigned`: consider nodes with no roles assigned
    '''
    res = []

    # kubernetes minions that not been bootstrapped yet
    # (ie, the role has been assigned in Velum)
    res.append('G@roles:kube-minion and not G@bootstrap_complete:true')

    if unassigned:
        # nodes with no role (preferring non-bootstrapped nodes)
        res.append('not P@roles:(kube-master|kube-minion|etcd) and not G@bootstrap_complete:true')
        res.append('not P@roles:(kube-master|kube-minion|etcd)')

    # etcd-only nodes (preferring non-bootstrapped nodes)
    res.append('G@roles:etcd and not G@roles:kube-master and not G@bootstrap_complete:true')
    res.append('G@roles:etcd and not G@roles:kube-master')

    return res


_PRIO_FUN = {
    'etcd': _get_prio_etcd,
    'kube-master': _get_prio_master,
    'kube-minion': _get_prio_minion,
}


# filter out empty/None and sort a list
def _sanitize_list(lst):
    res = [x for x in lst if x]
    res.sort()
    return res


def get_with_expr(expr, **kwargs):
    '''
    Get all the nodes that match some expression `expr`

    Optional arguments:

      * `booted`: exclude non-bootstrapped nodes
      * `exclude_admin`: exclude the Admin and CA nodes
      * `exclude_in_progress`: exclude any node with *_in_progress grains
      * `excluded`: list of nodes to exclude
      * `excluded_roles`: list of roles to exclude
    '''
    expr_items = [expr]

    if kwargs.get('booted', False):
        expr_items.append('G@bootstrap_complete:true')

    if kwargs.get('exclude_admin', False):
        expr_items.append('not P@roles:(admin|ca)')

    if kwargs.get('exclude_in_progress', False):
        expr_items.append('not G@bootstrap_in_progress:true')
        expr_items.append('not G@update_in_progress:true')
        expr_items.append('not G@removal_in_progress:true')
        expr_items.append('not G@addition_in_progress:true')

    excluded = _sanitize_list(kwargs.get('excluded', []))
    if excluded:
        expr_items.append('not L@' + '|'.join(excluded))

    excluded_roles = _sanitize_list(kwargs.get('excluded_roles', []))
    if excluded_roles:
        expr_items.append('not P@roles:(' + '|'.join(excluded_roles) + ')')

    return __salt__['caasp_grains.get'](' and '.join(expr_items)).keys()


def get_from_args_or_with_expr(arg_name, args_dict, *args, **kwargs):
    '''
    Utility function for getting a list of nodes from either the kwargs
    or from an expression.
    '''
    if arg_name in args_dict:
        return _sanitize_list(args_dict[arg_name])
    else:
        return get_with_expr(*args, **kwargs)


def get_with_prio(num, description, prio_rules, **kwargs):
    '''
    Get a list of `num` nodes that could be used for
    running some role.

    A valid node is a node that:

      1) is not the `admin` or `ca`
      2) dopes not currently have that role
      2) is not being removed/added/updated
    '''
    new_nodes = []
    remaining = num
    for expr in prio_rules:
        debug('trying to find candidates for %s with %s',
              description, expr)
        # get all the nodes matching the priority expression,
        # but filtering out all the nodes we already have
        candidates = get_with_expr(expr,
                                   exclude_admin=True, exclude_in_progress=True,
                                   **kwargs)
        ids = [x for x in candidates if x not in new_nodes]
        if len(ids) > 0:
            new_ids = ids[:remaining]
            new_nodes = new_nodes + new_ids
            remaining -= len(new_ids)
            debug('... %d new candidates (%s) for %s: %d remaining',
                  len(ids), str(ids), description, remaining, )
        else:
            debug('... no candidates found with %s', expr)

        if remaining <= 0:
            break

    info('we were looking for %d candidates for %s and %d found',
         num, description, len(new_nodes))
    return new_nodes[:num]


def get_with_prio_for_role(num, role, **kwargs):
    unassigned = kwargs.get('unassigned', False)
    prio_rules = _PRIO_FUN[role](unassigned)
    return get_with_prio(num, role, prio_rules, **kwargs)


def _get_one_for_role(role, **kwargs):
    res = get_with_prio_for_role(1, role, unassigned=True, **kwargs)
    return res[0] if len(res) > 0 else ''


def get_replacement_for(target, replacement='', **kwargs):
    '''
    When removing a node `target`, try to get a `replacement` (and the new roles that
    must be assigned) for all the roles that were running there.

    If the user provides an explicit `replacement`, verify that that replacement is valid.
    In case the user-provided is not valid, raise an exception (aborting the execution).

    If no replacement can be found, we are fine as long as we have a minimum number
    of nodes with that role (ie, for masters, we are fine as long as we have at least one master).
    '''
    assert target

    excluded = kwargs.get('excluded', [])

    replacement_provided = (replacement != '')
    replacement_roles = []

    def warn_or_abort_on_replacement_provided(msg, *args):
        if replacement_provided:
            abort('the user provided replacement cannot be used: ' + msg, *args)
        else:
            warn(msg, *args)

    # preparations

    # check: we cannot try to remove some 'virtual' nodes
    forbidden = get_from_args_or_with_expr(
        'forbidden', kwargs, 'P@roles:(admin|ca)')
    if target in forbidden:
        abort('%s cannot be removed: it has a "ca" or "admin" role',
              target)
    elif replacement_provided and replacement in forbidden:
        abort('%s cannot be replaced by %s: the replacement has a "ca" or "admin" role',
              target, replacement)

    masters = get_from_args_or_with_expr(
        'masters', kwargs, 'G@roles:kube-master')
    minions = get_from_args_or_with_expr(
        'minions', kwargs, 'G@roles:kube-minion')
    etcd_members = get_from_args_or_with_expr(
        'etcd_members', kwargs, 'G@roles:etcd')

    #
    # replacement for etcd members
    #
    if target in etcd_members:
        etcd_replacement = replacement
        if not etcd_replacement:
            debug('looking for replacement for etcd at %s', target)
            # we must choose another node and promote it to be an etcd member
            etcd_replacement = _get_one_for_role(
                'etcd', excluded=excluded)

        # check if the replacement provided is valid
        if etcd_replacement:
            bootstrapped_etcd_members = get_from_args_or_with_expr(
                'booted_etcd_members', kwargs, 'G@roles:kube-master', booted=True)

            if etcd_replacement in bootstrapped_etcd_members:
                warn_or_abort_on_replacement_provided('the replacement for the etcd server %s cannot be %s: another etcd server is already running there',
                                                      target, etcd_replacement)
                etcd_replacement = ''
            # the etcd replacement can be run in bootstrapped masters/minions,
            # so we are done with the incompatibility checks...

        if etcd_replacement:
            debug('setting %s as the replacement for the etcd member %s',
                  etcd_replacement, target)
            replacement = etcd_replacement
            replacement_roles.append('etcd')

        if not 'etcd' in replacement_roles:
            if len(etcd_members) <= _MIN_ETCD_MEMBERS_AFTER_REMOVAL:
                # we need at least one etcd server
                abort('cannot remove etcd member %s: too few etcd members, and no replacement found or provided',
                      target)
            else:
                warn('number of etcd members will be reduced to %d, as no replacement for etcd server in %s has been found (or provided)',
                     len(etcd_members), target)

    #
    # replacement for k8s masters
    #
    if target in masters:
        master_replacement = replacement
        if not master_replacement:
            # NOTE: even if no `replacement` was provided in the pillar,
            #       we probably have one at this point: if the master was
            #       running etcd as well, we have already tried to find
            #       a replacement in the previous step...
            #       however, we must verify that the etcd replacement
            #       is a valid k8s master replacement too.
            #       (ideally we should find the union of etcd and
            #       masters candidates)
            debug('looking for replacement for kubernetes master at %s', target)
            master_replacement = _get_one_for_role(
                'kube-master', excluded=excluded)

        # check if the replacement provided/found is valid
        if master_replacement:
            bootstrapped_masters = get_from_args_or_with_expr(
                'booted_masters', kwargs, 'G@roles:kube-master', booted=True)
            if master_replacement in bootstrapped_masters:
                warn_or_abort_on_replacement_provided('will not replace the k8s master %s: the replacement %s is already running a k8s master',
                                                      target, master_replacement)
                master_replacement = ''
            elif master_replacement in minions:
                warn_or_abort_on_replacement_provided('will not replace the k8s master at %s: the replacement found/provided is the k8s minion %s',
                                                      target, master_replacement)
                master_replacement = ''

        if master_replacement:
            # so far we do not support having two replacements for two roles,
            # so we check if the new replacement is compatible with any previous
            # replacement found so far. If it is not, keep the previous one and
            # warn the user
            if not replacement:
                replacement = master_replacement

            assert len(replacement) > 0
            if replacement == master_replacement:
                debug('setting %s as replacement for the kubernetes master %s',
                      replacement, target)
                replacement_roles.append('kube-master')
            else:
                warn('the k8s master replacement (%s) is not the same as the current replacement (%s) ' +
                     '(it will run %s) so we cannot use it for running the k8s master too',
                     master_replacement, replacement, ','.join(replacement_roles))

        if not 'kube-master' in replacement_roles:
            # stability check: check if it is ok not to run the k8s master in the replacement
            if len(masters) <= _MIN_MASTERS_AFTER_REMOVAL:
                # we need at least one master (for runing the k8s API at all times)
                abort('cannot remove k8s master %s: too few k8s masters, and no replacement found or provided',
                      target)
            else:
                warn('number of k8s masters will be reduced to %d, as no replacement for the k8s master in %s has been found (or provided)',
                     len(masters), target)

    #
    # replacement for k8s minions
    #
    if target in minions:
        minion_replacement = replacement
        if not minion_replacement:
            debug('looking for replacement for kubernetes minion at %s', target)
            minion_replacement = _get_one_for_role(
                'kube-minion', excluded=excluded)

        # check if the replacement provided/found is valid
        # NOTE: maybe the new role has already been assigned in Velum...
        if minion_replacement:
            bootstrapped_minions = get_from_args_or_with_expr(
                'booted_minions', kwargs, 'G@roles:kube-minion', booted=True)
            if minion_replacement in bootstrapped_minions:
                warn_or_abort_on_replacement_provided('will not replace minion %s: the replacement %s is already running a k8s minion',
                                                      target, minion_replacement)
                minion_replacement = ''

            elif minion_replacement in masters:
                warn_or_abort_on_replacement_provided('will not replace the k8s minion %s: the replacement %s is already a k8s master',
                                                      target, minion_replacement)
                minion_replacement = ''

            elif 'kube-master' in replacement_roles:
                warn_or_abort_on_replacement_provided('will not replace the k8s minion %s: the replacement found/provided, %s, is already scheduled for being a new k8s master',
                                                      target, minion_replacement)
                minion_replacement = ''

        if minion_replacement:
            # once again, check if the new replacement is compatible with any previous one
            if not replacement:
                replacement = minion_replacement

            assert len(replacement) > 0
            if replacement == minion_replacement:
                debug('setting %s as replacement for the k8s minion %s',
                      replacement, target)
                replacement_roles.append('kube-minion')
            else:
                warn('the k8s minion replacement (%s) is not the same as the current replacement (%s) ' +
                     '(it will run %s) so we cannot use it for running the k8s minion too',
                     minion_replacement, replacement, ','.join(replacement_roles))

        if not 'kube-minion' in replacement_roles:
            # stability check: check if it is ok not to run the k8s minion in the replacement
            if len(minions) <= _MIN_MINIONS_AFTER_REMOVAL:
                # we need at least one minion (for running dex, kube-dns, etc..)
                abort('cannot remove k8s minion %s: too few k8s minions, and no replacement found or provided',
                      target)
            else:
                warn('number of k8s minions will be reduced to %d, as no replacement for the k8s minion in %s has been found (or provided)',
                     len(masters), target)

    # other consistency checks...
    if replacement:
        # consistency check: if there is a replacement, it must have some (new) role(s)
        if not replacement_roles:
            abort('internal error: replacement %s has no roles assigned', replacement)
    else:
        # if no valid replacement has been found, clear the roles too
        replacement_roles = []

    return replacement, replacement_roles


def get_expr_affected_by(target, **kwargs):
    '''
    Get an expression for matching nodes that are affected by the
    addition/removal of `target`. Those affected nodes should
    be highstated in order to update their configuration.

    Some notes:

      * we only consider bootstraped nodes.
      * we ignore nodes where some oither operation is in progress (ie, an update)

    Optional arguments:

      * `exclude_in_progress`: (default=True) exclude any node with *_in_progress
      * `excluded`: list of nodes to exclude
      * `excluded_roles`: list of roles to exclude
    '''
    affected_items = []
    affected_roles = []

    etcd_members = get_from_args_or_with_expr('etcd_members', kwargs, 'G@roles:etcd')
    masters = get_from_args_or_with_expr('masters', kwargs, 'G@roles:kube-master')
    minions = get_from_args_or_with_expr('minions', kwargs, 'G@roles:kube-minion')

    if target in etcd_members:
        # we must highstate:
        # * etcd members (ie, peers list in /etc/sysconfig/etcd)
        affected_roles.append('etcd')
        # * api servers (ie, etcd endpoints in /etc/kubernetes/apiserver
        affected_roles.append('kube-master')

    if target in masters:
        # we must highstate:
        # * admin (ie, haproxy)
        affected_roles.append('admin')
        # * minions (ie, haproxy)
        affected_roles.append('kube-minion')

    if target in minions:
        # ok, ok, /etc/hosts will contain the old node, but who cares!
        pass

    if not affected_roles:
        debug('no roles affected by the removal/addition of %s', target)
        return ''

    affected_items.append('G@bootstrap_complete:true')

    affected_roles.sort()
    affected_items.append('P@roles:(' + '|'.join(affected_roles) + ')')

    if kwargs.get('exclude_in_progress', True):
        affected_items.append('not G@bootstrap_in_progress:true')
        affected_items.append('not G@update_in_progress:true')
        affected_items.append('not G@removal_in_progress:true')
        affected_items.append('not G@addition_in_progress:true')

    excluded_nodes = _sanitize_list([target] + kwargs.get('excluded', []))
    if excluded_nodes:
        affected_items.append('not L@' + ','.join(excluded_nodes))

    excluded_roles = _sanitize_list(kwargs.get('excluded_roles', []))
    if excluded_roles:
        affected_items.append('not P@roles:(' + '|'.join(excluded_roles) + ')')

    return ' and '.join(affected_items)


def get_super_master(**kwargs):
    '''
    Get one random master that can be used as super-master
    '''
    masters = get_from_args_or_with_expr('masters', kwargs, 'G@roles:kube-master')

    excluded = kwargs.get('excluded', [])

    for master in masters:
        if master not in excluded:
            return master

    return ''
