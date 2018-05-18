from __future__ import absolute_import

import unittest

import caasp_etcd
from caasp_etcd import ETCD_CLIENT_PORT, get_endpoints

try:
    from mock import patch, MagicMock
except ImportError:
    _mocking_lib_available = False
else:
    _mocking_lib_available = True


caasp_etcd.__salt__ = {}


class TestGetEndpoints(unittest.TestCase):
    '''
    Some basic tests for get_from_args_or_with_expr()
    '''

    def test_get_endpoints(self):
        nodes = {
            'AAA': 'node1',
            'BBB': 'node2',
            'CCC': 'node3'
        }

        mock = MagicMock(return_value=nodes)
        with patch.dict(caasp_etcd.__salt__, {'caasp_grains.get': mock}):
            res = get_endpoints()
            mock.assert_called_once_with('G@roles:etcd')

            for i in nodes.values():
                self.assertIn('https://{}:{}'.format(i, ETCD_CLIENT_PORT), res,
                              'did not get the expected list of etcd endpoints: {}'.format(res))

            mock.reset_mock()

            res = get_endpoints(with_id=True)
            mock.assert_called_once_with('G@roles:etcd')

            for (j, k) in nodes.items():
                self.assertIn('{}=https://{}:{}'.format(j, k, ETCD_CLIENT_PORT), res,
                              'did not get the expected list of etcd endpoints: {}'.format(res))

            mock.reset_mock()

            res = get_endpoints(skip_removed=True)
            mock.assert_called_once_with('G@roles:etcd and not G@node_removal_in_progress:true')

            mock.reset_mock()
