from __future__ import absolute_import

import unittest

import caasp_pillar
from caasp_log import ExecutionAborted
from caasp_pillar import get as get_pillar

try:
    from mock import patch, MagicMock
except ImportError:
    _mocking_lib_available = False
else:
    _mocking_lib_available = True


caasp_pillar.__salt__ = {}


class TestGetPillar(unittest.TestCase):
    '''
    Some basic tests for caasp_pillar.get()
    '''

    def test_get_pillar(self):

        mock = MagicMock()
        with patch.dict(caasp_pillar.__salt__, {'pillar.get': mock}):
            # check we get a integer
            mock.return_value = '123'
            res = get_pillar('some_int_pillar')
            self.assertTrue(isinstance(res, int),
                            'expected to get a integer: {}'.format(res))
            mock.reset_mock()

            # check we get a boolean
            for value in ['true', 'on', 'TRUE']:
                mock.return_value = value
                res = get_pillar('some_bool_pillar')
                self.assertTrue(isinstance(res, bool),
                                'expected to get a bool: {}'.format(res))
                mock.reset_mock()

            # check we get a string
            mock.return_value = 'something'
            res = get_pillar('some_str_pillar')
            self.assertTrue(isinstance(res, str),
                            'expected to get a string: {}'.format(res))
            mock.reset_mock()
