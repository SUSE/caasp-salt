from __future__ import absolute_import

import unittest

import caasp_etcd
from caasp_etcd import get_reorg

try:
    from mock import patch, MagicMock
except ImportError:
    _mocking_lib_available = False
else:
    _mocking_lib_available = True


caasp_etcd.__salt__ = {}


class TestGetReorg(unittest.TestCase):
    '''
    Some basic tests for get_reorg()
    '''

    def test_get_reorg(self):

        from caasp_utils import intersect
        from caasp_nodes import get_from_args_or_with_expr

        mocks_dict = {
            'caasp_nodes.get_from_args_or_with_expr': get_from_args_or_with_expr,
            'caasp_utils.intersect': intersect,
        }

        with patch.dict(caasp_etcd.__salt__, mocks_dict):
            nodes = ['node{}'.format(i) for i in xrange(10)]

            #
            # check that
            #   * 1 new master (without etcd)
            #   * 1 minion running etcd
            # leads to 1 etcd migrations
            #
            masters = nodes[:2]
            minions = nodes[2:]
            etcd_members = [nodes[1], nodes[2]]      # one master and one minion

            new_etcd, old_etcd = get_reorg([nodes[0]],
                                           masters=masters,
                                           minions=minions,
                                           etcd_members=etcd_members)

            self.assertTrue(len(new_etcd) == 1,
                            'unexpected number of new etcd nodes: got {} (masters={}, minions={}, etc={})'.format(
                            new_etcd, masters, minions, etcd_members))
            self.assertTrue(len(old_etcd) == 1,
                            'unexpected number of old etcd nodes: got {} (masters={}, minions={}, etc={})'.format(
                            old_etcd, masters, minions, etcd_members))
            self.assertIn(nodes[0], new_etcd,
                          'expected node0 to be in the new etcd members, but got {} (masters={}, minions={}, etc={})'.format(
                          new_etcd, masters, minions, etcd_members))
            self.assertIn(nodes[2], old_etcd,
                          'expected node2 to be in the old etcd members, but got {} (masters={}, minions={}, etc={})'.format(
                          old_etcd, masters, minions, etcd_members))

            #
            # check that
            #   * 1 new master and 1 new minion (without etcd)
            #   * 1 minion running etcd
            # leads to 1 etcd migration
            #
            masters = nodes[:4]
            minions = nodes[4:]
            etcd_members = [nodes[2], nodes[3], nodes[4]]

            new_etcd, old_etcd = get_reorg([nodes[0], nodes[5]],
                                           masters=masters,
                                           minions=minions,
                                           etcd_members=etcd_members)

            self.assertTrue(len(new_etcd) == 1,
                            'unexpected number of new etcd nodes: got {} (masters={}, minions={}, etc={})'.format(
                            new_etcd, masters, minions, etcd_members))
            self.assertTrue(len(old_etcd) == 1,
                            'unexpected number of old etcd nodes: got {} (masters={}, minions={}, etc={})'.format(
                            old_etcd, masters, minions, etcd_members))
            self.assertIn(nodes[0], new_etcd,
                          'expected node0 to be in the new etcd members, but got {} (masters={}, minions={}, etc={})'.format(
                          new_etcd, masters, minions, etcd_members))
            self.assertIn(nodes[4], old_etcd,
                          'expected node4 to be in the old etcd members, but got {} (masters={}, minions={}, etc={})'.format(
                          old_etcd, masters, minions, etcd_members))

            #
            # check that
            #   * 2 new masters without etcd
            #   * 2 minions running etcd
            # leads to 2 etcd migrations
            #
            masters = nodes[:4]
            minions = nodes[4:]
            etcd_members = [nodes[2], nodes[3], nodes[4], nodes[5]]

            new_etcd, old_etcd = get_reorg([nodes[0], nodes[1], nodes[5]],
                                           masters=masters,
                                           minions=minions,
                                           etcd_members=etcd_members)

            self.assertTrue(len(new_etcd) == 2,
                            'unexpected number of new etcd nodes: got {} (masters={}, minions={}, etc={})'.format(
                            new_etcd, masters, minions, etcd_members))
            self.assertTrue(len(old_etcd) == 2,
                            'unexpected number of old etcd nodes: got {} (masters={}, minions={}, etc={})'.format(
                            old_etcd, masters, minions, etcd_members))
            self.assertIn(nodes[0], new_etcd,
                          'expected node0 to be in the new etcd members, but got {} (masters={}, minions={}, etc={})'.format(
                          new_etcd, masters, minions, etcd_members))
            self.assertIn(nodes[1], new_etcd,
                          'expected node1 to be in the new etcd members, but got {} (masters={}, minions={}, etc={})'.format(
                          new_etcd, masters, minions, etcd_members))
            self.assertIn(nodes[4], old_etcd,
                          'expected node4 to be in the old etcd members, but got {} (masters={}, minions={}, etc={})'.format(
                          old_etcd, masters, minions, etcd_members))
            self.assertIn(nodes[5], old_etcd,
                          'expected node5 to be in the old etcd members, but got {} (masters={}, minions={}, etc={})'.format(
                          old_etcd, masters, minions, etcd_members))

            #
            # check that
            #   * 2 new masters without etcd
            #   * 1 minion running etcd
            # leads to only one etcd migration
            #
            masters = nodes[:4]
            minions = nodes[4:]
            etcd_members = [nodes[2], nodes[3], nodes[4]]

            new_etcd, old_etcd = get_reorg([nodes[0], nodes[1], nodes[5]],
                                           masters=masters,
                                           minions=minions,
                                           etcd_members=etcd_members)

            self.assertTrue(len(new_etcd) == 1,
                            'unexpected number of new etcd nodes: got {} (masters={}, minions={}, etc={})'.format(
                            new_etcd, masters, minions, etcd_members))
            self.assertTrue(len(old_etcd) == 1,
                            'unexpected number of old etcd nodes: got {} (masters={}, minions={}, etc={})'.format(
                            old_etcd, masters, minions, etcd_members))
            self.assertIn(nodes[0], new_etcd,
                          'expected node0 to be in the new etcd members, but got {} (masters={}, minions={}, etc={})'.format(
                          new_etcd, masters, minions, etcd_members))
            self.assertIn(nodes[4], old_etcd,
                          'expected node4 to be in the old etcd members, but got {} (masters={}, minions={}, etc={})'.format(
                          old_etcd, masters, minions, etcd_members))

            #
            # check that
            #   * 2 new minion without etcd
            #   * 1 minion running etcd
            # leads to no etcd migrations
            #
            masters = nodes[:4]
            minions = nodes[4:]
            etcd_members = [nodes[2], nodes[3], nodes[4]]

            new_etcd, old_etcd = get_reorg([nodes[5], nodes[6]],
                                           masters=masters,
                                           minions=minions,
                                           etcd_members=etcd_members)

            self.assertTrue(len(new_etcd) == 0,
                            'unexpected number of new etcd nodes: got {} (masters={}, minions={}, etc={})'.format(
                            new_etcd, masters, minions, etcd_members))
            self.assertTrue(len(old_etcd) == 0,
                            'unexpected number of old etcd nodes: got {} (masters={}, minions={}, etc={})'.format(
                            old_etcd, masters, minions, etcd_members))
