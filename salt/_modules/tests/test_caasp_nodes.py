from __future__ import absolute_import

import unittest

from caasp_log import ExecutionAborted
from caasp_nodes import (get_expr_affected_by, get_from_args_or_with_expr,
                         get_replacement_for, get_with_prio)

try:
    from mock import patch, MagicMock
except ImportError:
    _mocking_lib_available = False
else:
    _mocking_lib_available = True


class TestGetFromArgsOrWithExpr(unittest.TestCase):
    '''
    Some basic tests for get_from_args_or_with_expr()
    '''

    def test_get_from_args_or_with_expr(self):
        def do_test(**kwargs):
            with patch('caasp_nodes.get_with_expr', MagicMock(return_value=[4, 5, 6])):
                return get_from_args_or_with_expr(
                    'etcd_members', kwargs, 'G@roles:etcd')

        res = do_test(etcd_members=[1, 2, 3])
        self.assertEqual(res, [1, 2, 3],
                         'did not get the etcd members from the kwargs: {}'.format(res))

        res = do_test(masters=[1, 2, 3])
        self.assertEqual(res, [4, 5, 6],
                         'did not get the masters with the expresion: {}'.format(res))


class TestGetWithPrio(unittest.TestCase):
    '''
    Some basic tests for get_with_prio()
    '''

    def setUp(self):
        self.unassigned_node_1 = 'unassigned_node_1'
        self.unassigned_node_2 = 'unassigned_node_2'
        self.unassigned_node_3 = 'unassigned_node_3'

    @unittest.skipIf(not _mocking_lib_available,
                     "no mocking library available (install rpm:python-mock)")
    def test_get_with_prio_for_etcd(self):
        '''
        Check get_with_prio() tries to get as many nodes as
        we requested.
        '''
        from caasp_nodes import _get_prio_etcd
        etcd_prio = _get_prio_etcd()

        counter = {'value': 0}

        def mocked_get_with_expr(expr, **kwargs):
            counter['value'] += 1
            return [self.unassigned_node_1]

        # we return always unassigned_node_1, so we should
        # exahust the priorities list looking for more nodes
        with patch('caasp_nodes.get_with_expr', mocked_get_with_expr):
            nodes = get_with_prio(2, 'etcd', etcd_prio)

            self.assertIn(self.unassigned_node_1, nodes,
                          'unassigned_node_1 not found in list')
            self.assertEqual(counter['value'], len(etcd_prio),
                             'priority list was not exahusted')

        counter = {'value': 0}

        def mocked_get_with_expr(expr, **kwargs):
            counter['value'] += 1
            return [self.unassigned_node_1, self.unassigned_node_2]

        # now we will get all the nodes required in just one call
        with patch('caasp_nodes.get_with_expr', mocked_get_with_expr):
            nodes = get_with_prio(2, 'etcd', etcd_prio)

            self.assertIn(self.unassigned_node_1, nodes,
                          'unassigned_node_1 not found in list')
            self.assertIn(self.unassigned_node_2, nodes,
                          'unassigned_node_2 not found in list')
            self.assertEqual(counter['value'], 1,
                             'unexpected number of calls ({}) to get_with_expr()'.format(counter['value']))

        counter = {'value': 0}

        def mocked_get_with_expr(expr, **kwargs):
            counter['value'] += 1
            return {1: [self.unassigned_node_1],
                    2: [self.unassigned_node_1, self.unassigned_node_2],
                    3: [self.unassigned_node_1, self.unassigned_node_2, self.unassigned_node_3]}[counter['value']]

        # now we will return one more node every time we
        # invoke get_with_expr()
        with patch('caasp_nodes.get_with_expr',
                   mocked_get_with_expr):
            nodes = get_with_prio(3, 'etcd', etcd_prio)

            self.assertIn(self.unassigned_node_1, nodes,
                          'unassigned_node_1 not found in list')
            self.assertIn(self.unassigned_node_2, nodes,
                          'unassigned_node_2 not found in list')
            self.assertIn(self.unassigned_node_3, nodes,
                          'unassigned_node_3 not found in list')
            self.assertEqual(counter['value'], 3,
                             'unexpected number of calls ({}) to get_with_expr()'.format(counter['value']))


class TestGetReplacementFor(unittest.TestCase):
    '''
    Some basic tests for get_replacement_for()
    '''

    def setUp(self):
        self.ca = 'ca'
        self.master_1 = 'master_1'
        self.master_2 = 'master_2'
        self.master_3 = 'master_3'
        self.minion_1 = 'minion_1'
        self.minion_2 = 'minion_2'
        self.minion_3 = 'minion_3'
        self.other_node = 'other_node'

        self.masters = [self.master_1, self.master_2, self.master_3]
        self.etcd_members = [self.master_1, self.master_2, self.master_3]
        self.minions = [self.minion_1, self.minion_2, self.minion_3]

        self.get_replacement_for_kwargs = {
            'forbidden': [self.ca],
            'etcd_members': self.etcd_members,
            'masters': self.masters,
            'minions': self.minions,
            'booted_etcd_members': self.etcd_members,
            'booted_masters': self.masters,
            'booted_minions': self.minions
        }

    def test_user_provided_for_etc_master(self):
        '''
        Check the user-provided etcd & master replacement is valid,
        at least for some roles
        '''
        replacement, roles = get_replacement_for(self.master_2,
                                                 replacement=self.other_node,
                                                 **self.get_replacement_for_kwargs)

        self.assertEqual(replacement, self.other_node,
                         'unexpected replacement')
        self.assertIn('etcd', roles,
                      'etcd role not found in replacement')
        self.assertIn('kube-master', roles,
                      'kube-master role not found in replacement')
        self.assertNotIn('kube-minion', roles,
                         'kube-minion role found in replacement')

    def test_user_provided_for_etcd_minion(self):
        '''
        Check the user-provided etcd & minion replacement is valid,
        at least for some roles
        '''
        # add one of the minions to the etcd cluster
        etcd_members = [self.master_1, self.master_2, self.minion_1]

        self.get_replacement_for_kwargs.update({
            'etcd_members': etcd_members,
            'booted_etcd_members': etcd_members,
        })

        replacement, roles = get_replacement_for(self.minion_1,
                                                 replacement=self.other_node,
                                                 **self.get_replacement_for_kwargs)

        # when removing minion_1 (with roles minion and etcd), we can migrate
        # both roles to a free node
        self.assertEqual(replacement, self.other_node,
                         'unexpected replacement')
        self.assertIn('etcd', roles,
                      'etcd role not found in replacement')
        self.assertNotIn('kube-master', roles,
                         'kube-master role found in replacement')
        self.assertIn('kube-minion', roles,
                      'kube-minion role not found in replacement')

        # however, we can migrate only the etcd role to another minion
        # (as it is a user provided replacement, it will raise an exception)
        with self.assertRaises(ExecutionAborted):
            replacement, roles = get_replacement_for(self.minion_1,
                                                     replacement=self.minion_3,
                                                     **self.get_replacement_for_kwargs)

    def test_user_provided_for_minion(self):
        '''
        Check the user-provided minion replacement is valid,
        at least for some roles
        '''
        replacement, roles = get_replacement_for(self.minion_3,
                                                 replacement=self.other_node,
                                                 **self.get_replacement_for_kwargs)

        # the minion role should be migrated to other_node
        self.assertEqual(replacement, self.other_node,
                         'unexpected replacement')
        self.assertNotIn('etcd', roles,
                         'etcd role found in replacement')
        self.assertNotIn('kube-master', roles,
                         'kube-master role found in replacement')
        self.assertIn('kube-minion', roles,
                      'kube-minion role not found in replacement')

    def test_invalid_etcd_replacement(self):
        '''
        Check get_replacement_for() realizes a minion
        is not a valid replacement for a master & etcd.
        '''
        # the master role cannot be migrated to a minion
        with self.assertRaises(ExecutionAborted):
            replacement, roles = get_replacement_for(self.master_2,
                                                     replacement=self.minion_3,
                                                     **self.get_replacement_for_kwargs)

    def test_forbidden_replacement(self):
        '''
        Check get_replacement_for() realizes the CA
        is not a valid replacement.
        '''
        # the master role cannot be migrated to a CA
        with self.assertRaises(ExecutionAborted):
            replacement, roles = get_replacement_for(self.master_2,
                                                     replacement=self.ca,
                                                     **self.get_replacement_for_kwargs)

    def test_forbidden_target(self):
        '''
        Check get_replacement_for() realizes the CA
        cannot be removed
        '''
        with self.assertRaises(ExecutionAborted):
            replacement, roles = get_replacement_for(self.ca,
                                                     replacement=self.minion_3,
                                                     **self.get_replacement_for_kwargs)

    @unittest.skipIf(not _mocking_lib_available,
                     "no mocking library available (install rpm:python-mock)")
    def test_auto_etcd_replacement(self):
        '''
        Check we can get a replacement for a master, migrating all the
        roles we can to that replacement...
        '''
        with patch('caasp_nodes._get_one_for_role', MagicMock(return_value=self.other_node)):

            replacement, roles = get_replacement_for(self.master_2,
                                                     **self.get_replacement_for_kwargs)

            # we can migrate both the master and the etcd role to a empty node
            self.assertEqual(replacement, self.other_node,
                             'unexpected replacement')
            self.assertIn('etcd', roles,
                          'etcd role not found in replacement')
            self.assertIn('kube-master', roles,
                          'kube-master role not found in replacement')
            self.assertNotIn('kube-minion', roles,
                             'kube-minion role found in replacement')

        with patch('caasp_nodes._get_one_for_role', MagicMock(return_value=self.minion_1)):

            replacement, roles = get_replacement_for(self.master_2,
                                                     **self.get_replacement_for_kwargs)

            # we can only migrate the etcd role (and not the master role) to a minion
            self.assertEqual(replacement, self.minion_1,
                             'unexpected replacement')
            self.assertIn('etcd', roles,
                          'etcd role not found in replacement')
            self.assertNotIn('kube-master', roles,
                             'kube-master role not found in replacement')


class TestGetExprAffectedBy(unittest.TestCase):
    '''
    Some basic tests for get_expr_affected_by()
    '''

    def setUp(self):
        self.ca = 'ca'
        self.master_1 = 'master_1'
        self.master_2 = 'master_2'
        self.master_3 = 'master_3'
        self.minion_1 = 'minion_1'
        self.minion_2 = 'minion_2'
        self.minion_3 = 'minion_3'
        self.other_node = 'other_node'
        self.only_etcd_1 = 'only_etcd_1'

        self.masters = [self.master_1, self.master_2, self.master_3]
        self.etcd_members = [self.master_1, self.master_2,
                             self.master_3, self.only_etcd_1]
        self.minions = [self.minion_1, self.minion_2, self.minion_3]

        self.common_expected_affected_matches = [
            'G@bootstrap_complete:true',
            'not G@bootstrap_in_progress:true',
            'not G@update_in_progress:true',
            'not G@removal_in_progress:true',
            'not G@addition_in_progress:true'
        ]

    def test_get_expr_affected_by_master_removal(self):
        '''
        Calculate the exporession for matching nodes affected by
        a master (k8s master & etcd) node removal
        '''
        affected_expr = get_expr_affected_by(self.master_1,
                                             masters=self.masters,
                                             minions=self.minions,
                                             etcd_members=self.etcd_members)

        affected_items = affected_expr.split(' and ')
        expected_matches = self.common_expected_affected_matches + [
            'P@roles:(admin|etcd|kube-master|kube-minion)',
            'not L@master_1',
        ]

        for expr in expected_matches:
            self.assertIn(expr, affected_items,
                          '{} is not in affected in expr: {}'.format(expr, affected_expr))

    def test_get_expr_affected_by_etcd_removal(self):
        '''
        Calculate the expression for matching nodes affected by
        a etcd-only node removal
        '''
        affected_expr = get_expr_affected_by(self.only_etcd_1,
                                             masters=self.masters,
                                             minions=self.minions,
                                             etcd_members=self.etcd_members)

        affected_items = affected_expr.split(' and ')
        expected_matches = self.common_expected_affected_matches + [
            'P@roles:(etcd|kube-master)',
            'not L@only_etcd_1']

        for expr in expected_matches:
            self.assertIn(expr, affected_items,
                          '{} is not in affected in expr: {}'.format(expr, affected_expr))

    def test_get_expr_affected_by_etcd_removal_with_excluded(self):
        '''
        Same test, but with some excluded node
        '''
        affected_expr = get_expr_affected_by(self.only_etcd_1,
                                             excluded=[self.master_2],
                                             masters=self.masters,
                                             minions=self.minions,
                                             etcd_members=self.etcd_members)

        affected_items = affected_expr.split(' and ')
        expected_matches = self.common_expected_affected_matches + [
            'P@roles:(etcd|kube-master)',
            'not L@master_2,only_etcd_1']

        for expr in expected_matches:
            self.assertIn(expr, affected_items,
                          '{} is not in affected in expr: {}'.format(expr, affected_expr))


if __name__ == '__main__':
    unittest.main()
