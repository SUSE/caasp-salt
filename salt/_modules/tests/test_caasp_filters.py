from __future__ import absolute_import

import unittest

import caasp_filters


class TestIsIP(unittest.TestCase):
    def test_is_ipv4(self):
        # Valid IPv4 addresses.
        self.assertTrue(caasp_filters.is_ipv4("127.0.0.1"))
        self.assertTrue(caasp_filters.is_ipv4("192.168.23.1"))
        self.assertTrue(caasp_filters.is_ipv4("192.168.23.255"))
        self.assertTrue(caasp_filters.is_ipv4("255.255.255.255"))
        self.assertTrue(caasp_filters.is_ipv4("0.0.0.0"))

        # Invalid IPv4 addresses.
        self.assertFalse(caasp_filters.is_ipv4("30.168.1.255.1"))
        self.assertFalse(caasp_filters.is_ipv4("127.1"))
        self.assertFalse(caasp_filters.is_ipv4("-1.0.2.3"))
        self.assertFalse(caasp_filters.is_ipv4("3...3"))
        self.assertFalse(caasp_filters.is_ipv4("whatever"))

        # see bsc#1123291
        self.assertFalse(caasp_filters.is_ipv4("master85.test.net"))

    def test_is_ipv6(self):
        self.assertTrue(
            caasp_filters.is_ipv6("1111:2222:3333:4444:5555:6666:7777:8888")
        )
        self.assertTrue(
            caasp_filters.is_ipv6("1111:2222:3333:4444:5555:6666:7777::")
        )
        self.assertTrue(caasp_filters.is_ipv6("::"))
        self.assertTrue(caasp_filters.is_ipv6("::8888"))

        self.assertFalse(
            caasp_filters.is_ipv6("11112222:3333:4444:5555:6666:7777:8888")
        )
        self.assertFalse(caasp_filters.is_ipv6("1111:"))
        self.assertFalse(caasp_filters.is_ipv6("::."))


if __name__ == '__main__':
    unittest.main()
