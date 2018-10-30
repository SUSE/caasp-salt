from __future__ import absolute_import

import unittest
import subprocess

import caasp_etcd
from caasp_etcd import ETCD_CLIENT_PORT, get_endpoints, get_current_endpoints, get_current_endpoints_with_self
from . import Utils

try:
    from mock import patch, MagicMock
except ImportError:
    _mocking_lib_available = False
else:
    _mocking_lib_available = True


caasp_etcd.__salt__ = {}
caasp_etcd.__utils__ = Utils()


class TestGetEndpoints(unittest.TestCase):
    '''
    Some basic tests for get_endpoints()
    '''

    def nodes(self):
        return {
            'AAA': 'node1',
            'BBB': 'node2',
            'CCC': 'node3'
        }

    def patch_salt(self, mock):
        return {
            'caasp_nodes.is_first_bootstrap': lambda: True,
            'caasp_grains.get': mock
        }

    def setUp(self):
        self.mock = MagicMock(return_value=self.nodes())
        patcher = patch.dict(caasp_etcd.__salt__, self.patch_salt(self.mock))
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_get_endpoints(self):
        res = get_endpoints()
        self.mock.assert_called_once_with('G@roles:etcd')

        for i in self.nodes().values():
            self.assertIn('https://{}:{}'.format(i, ETCD_CLIENT_PORT), res,
                          'did not get the expected list of etcd endpoints: {}'.format(res))

    def test_get_endpoints_with_id(self):
        res = get_endpoints(with_id=True)
        self.mock.assert_called_once_with('G@roles:etcd')

        for (j, k) in self.nodes().items():
            self.assertIn('{}=https://{}:{}'.format(j, k, ETCD_CLIENT_PORT), res,
                          'did not get the expected list of etcd endpoints: {}'.format(res))

    def test_get_endpoints_with_skip_removed(self):
        get_endpoints(skip_removed=True)
        self.mock.assert_called_once_with('G@roles:etcd and not G@node_removal_in_progress:true')


class TestGetCurrentEndpoints(unittest.TestCase):
    '''
    Some basic tests for get_current_endpoints()
    '''

    def grains_get(self, grain):
        if grain == 'nodename':
            return 'new_nodename'
        elif grain == 'id':
            return 'new_id'

    def patch_salt(self):
        return {
            'grains.get': lambda grain: self.grains_get(grain)
        }

    def setUp(self):
        patcher = patch.dict(caasp_etcd.__salt__, self.patch_salt())
        patcher.start()
        self.addCleanup(patcher.stop)

    def member_item(self, member_id, name, peer_urls, client_urls, is_leader):
        return {
            'member_id': member_id,
            'name': name,
            'peer_urls': peer_urls,
            'client_urls': client_urls,
            'is_leader': is_leader
        }

    def member_list(self, port=ETCD_CLIENT_PORT):
        return {
            'active': [
                self.member_item('member_id_1', 'id_1', 'https://nodename_1:{}'.format(port), 'https://nodename_1:2379', 'true'),
                self.member_item('member_id_2', 'id_2', 'https://nodename_2:{}'.format(port), 'https://nodename_2:2379', 'false'),
                self.member_item('member_id_3', 'id_3', 'https://nodename_3:{}'.format(port), 'https://nodename_3:2379', 'false')
            ]
        }

    def nodes(self, port=ETCD_CLIENT_PORT):
        result = {}

        for i, member in enumerate(self.member_list(port=port)['active']):
            result['id_{}'.format(i + 1)] = 'nodename_{}'.format(i + 1)

        return result

    def mapped_member_list(self, with_id=False, extra_items=[], port=ETCD_CLIENT_PORT):
        result = []
        for peer in self.member_list(port=port)['active'] + extra_items:
            peer_urls = peer['peer_urls']
            if with_id:
                peer_urls = '{}={}'.format(peer['name'], peer['peer_urls'])
            result.append(peer_urls)

        return result

    def new_member_item(self):
        return self.member_item('new_member_id', 'new_id', 'https://new_nodename:2380', 'https://new_nodename:2379', 'false')

    @patch.object(caasp_etcd, 'member_list', autospec=True)
    def test_get_current_endpoints(self, mock_member_list):
        mock_member_list.return_value = self.member_list()
        res = get_current_endpoints()
        self.assertEqual(res, ','.join(self.mapped_member_list()))

    @patch.object(caasp_etcd, 'member_list', autospec=True)
    def test_get_current_endpoints_with_port(self, mock_member_list):
        mock_member_list.return_value = self.member_list(port=2222)
        res = get_current_endpoints(port=2222)
        self.assertEqual(res, ','.join(self.mapped_member_list(port=2222)))

    @patch.object(caasp_etcd, 'member_list', autospec=True)
    def test_get_current_endpoints_with_self(self, mock_member_list):
        mock_member_list.return_value = self.member_list(port=2380)
        res = get_current_endpoints_with_self(port=2380)
        self.assertEqual(res, ','.join(self.mapped_member_list(with_id=True, port=2380, extra_items=[self.new_member_item()])))

    @patch.object(caasp_etcd, 'get_current_endpoints_raw', autospec=True)
    def test_get_current_endpoints_with_self_failing_current_endpoints(self, mock_get_current_endpoints_raw):
        '''
        When `get_current_endpoints_with_self` fails to retrieve the result from
        `etcdctl member list`, we fallback to `get_endpoints`
        '''
        with patch.dict(caasp_etcd.__salt__, {'caasp_nodes.is_first_bootstrap': lambda: False, 'caasp_grains.get': lambda expr: self.nodes(port=2380)}):
            mock_get_current_endpoints_raw.side_effect = subprocess.CalledProcessError(returncode=1, cmd='cmd', output='')
            res = get_current_endpoints_with_self(port=2380)
            self.assertEqual(res, ','.join(self.mapped_member_list(with_id=True, port=2380, extra_items=[self.new_member_item()])))
