from __future__ import absolute_import

import logging
import os
import random
import unittest

from salt.utils.odict import OrderedDict
from . import Utils

try:
    from mock import patch, MagicMock
except ImportError:
    _mocking_lib_available = False
else:
    _mocking_lib_available = True

log = logging.getLogger()
log.level = logging.DEBUG

TEMP_PREFIX = 'caasp-hosts-tmp'

MARKER_START = "#-- start Salt-CaaSP managed hosts - DO NOT MODIFY --"

MARKER_END = "#-- end Salt-CaaSP managed hosts --"

EXTERNAL_MASTER_NAME = 'external.name.com'


def log_block(name, contents, description=''):
    if isinstance(contents, list):
        lines = contents
    else:
        lines = contents.splitlines()

    log.debug('')
    if description:
        log.debug('%s:', description)
    log.debug('%s:', name)
    if lines:
        for line in lines:
            log.debug('%s: %s', name, line)
    else:
        log.debug('%s: <empty>', name)
    log.debug('')


class TestEtcHosts(unittest.TestCase):
    '''
    Some basic tests for loading /etc/hosts
    '''

    def _generate(self, etc_hosts_filename, caasp_etc_hosts_filename, role='kube-master'):
        import caasp_hosts
        caasp_hosts.__salt__ = dict()
        caasp_hosts.__utils__ = Utils()

        ips = {
            'admin': '10.10.10.1',
            'master0': '10.10.10.2',
            'minion1': '10.10.10.3',
            'other0': '10.10.10.4'
        }

        admin_nodes = {'admin': 'eth0'}
        master_nodes = {'master0': 'eth0'}
        worker_nodes = {'minion1': 'eth0'}
        other_nodes = {'other0': 'eth0'}

        def mock_get_primary_ip(host, ifaces):
            return ips[host]

        def mock_get_nodename(host):
            return host

        def mock_get_pillar(s, default=None):
            return {
                caasp_hosts.PILLAR_INTERNAL_INFRA: 'infra.caasp.local',
                caasp_hosts.PILLAR_EXTERNAL_FQDN: EXTERNAL_MASTER_NAME
            }[s]

        def mock_get_grains(s, default=None):
            if role == 'kube-master':
                return {
                    'localhost': 'master0',
                    'roles': ['kube-master', 'etcd']
                }[s]
            elif role == 'admin':
                return {
                    'localhost': 'admin',
                    'roles': ['admin']
                }[s]

        salt_mocks = {
            'grains.get': mock_get_grains,
            'caasp_pillar.get': mock_get_pillar,
            'caasp_net.get_primary_ip': mock_get_primary_ip,
            'caasp_net.get_nodename': mock_get_nodename,
            'caasp_filters.is_ip': MagicMock(return_value=False),
        }

        with patch.dict(caasp_hosts.__salt__, salt_mocks):
            changes = caasp_hosts.managed(name=etc_hosts_filename,
                                          admin_nodes=admin_nodes,
                                          master_nodes=master_nodes,
                                          worker_nodes=worker_nodes,
                                          other_nodes=other_nodes,
                                          caasp_hosts_file=caasp_etc_hosts_filename,
                                          marker_start=MARKER_START,
                                          marker_end=MARKER_END)
        return changes

    def test_simple_load_hosts(self):

        current_etc_hosts_contents = '''
#
# IP-Address  Full-Qualified-Hostname  Short-Hostname
#
127.0.0.1	localhost

# special IPv6 addresses
::1             localhost ipv6-localhost ipv6-loopback

fe00::0         ipv6-localnet

ff00::0         ipv6-mcastprefix
ff02::1         ipv6-allnodes
ff02::2         ipv6-allrouters
ff02::3         ipv6-allhosts

# some other name someone/something introduced for Admin
# it should be merged with the IP we will set for Admin
10.10.10.1      some-other-name-for-admin

# some custom and unrelated name
10.10.10.9      custom-name

#-- start Salt-CaaSP managed hosts - DO NOT MODIFY --

# these entries were added by Salt before having "caasp_hosts"
# they should be ignored now
10.10.9.1  admin
10.10.9.2  master0
10.10.9.3  minion1
10.10.9.4  other0

#-- end Salt-CaaSP managed hosts --
'''

        from tempfile import NamedTemporaryFile as ntf
        import caasp_hosts
        caasp_hosts.__utils__ = Utils()

        with ntf(mode='w+', prefix=TEMP_PREFIX) as etc_hosts:
            try:
                caasp_etc_hosts_filename = '/tmp/caasp-hosts-{}'.format(random.randrange(0, 1000))

                # write the "current" /etc/hosts file
                etc_hosts.write(current_etc_hosts_contents)
                etc_hosts.seek(0)
                log_block('/etc/hosts', etc_hosts.read(),
                          description='/etc/hosts contents BEFORE calling managed()')

                #
                # story: first run of caasp_hosts.managed()
                #        this is what we will find after updating from
                #        the previous mechanism to the new system
                #        with caasp_hosts
                #
                changes = self._generate(etc_hosts.name, caasp_etc_hosts_filename)

                etc_hosts.seek(0)
                new_contents = etc_hosts.read()
                log_block('/etc/hosts', new_contents,
                          description='/etc/hosts contents AFTER calling managed()')
                log_block('changes', changes)

                with open(caasp_etc_hosts_filename, 'r') as chf:
                    log_block('/etc/caasp/hosts', chf.read(),
                              description='Saved /etc/caasp/hosts file')

                # load the /etc/hosts we have generated and check
                # some entries are there
                new_etc_hosts_contents = OrderedDict()
                caasp_hosts._load_hosts_file(new_etc_hosts_contents,
                                             etc_hosts.name)

                def check_entry(ip, names):
                    self.assertIn(ip, new_etc_hosts_contents)
                    for name in names:
                        self.assertIn(name, new_etc_hosts_contents[ip])

                # check the Admin node has the right entries
                check_entry('10.10.10.1', ['admin',
                                           'some-other-name-for-admin'])

                # check we are setting the right things in 127.0.0.1
                check_entry('127.0.0.1', ['api', 'api.infra.caasp.local',
                                          EXTERNAL_MASTER_NAME,
                                          'localhost',
                                          'master0', 'master0.infra.caasp.local'])

                # check other entries
                check_entry('10.10.10.9', ['custom-name'])

                # check the old entries atre not present
                for ip in ['10.10.9.1', '10.10.9.2', '10.10.9.3', '10.10.9.4']:
                    self.assertNotIn(ip, new_etc_hosts_contents)

                #
                # story: this host is highstated again
                #        we must check the idempotency of 'caasp_hosts'
                #

                prev_etc_hosts_contents = new_etc_hosts_contents

                changes = self._generate(etc_hosts.name, caasp_etc_hosts_filename)

                etc_hosts.seek(0)
                new_contents = etc_hosts.read()
                log_block('/etc/hosts', new_contents,
                          description='/etc/hosts contents AFTER calling managed AGAIN()')
                log_block('changes', changes, description='we do not expect any changes here')

                # check some entries are still there
                new_etc_hosts_contents = OrderedDict()
                caasp_hosts._load_hosts_file(new_etc_hosts_contents,
                                             etc_hosts.name)

                self.assertDictEqual(prev_etc_hosts_contents, new_etc_hosts_contents)
                self.assertTrue(len(changes) == 0, 'changes have been found')

                #
                # story: user adds some custom entries in /etc/caasp/hosts
                #

                with open(caasp_etc_hosts_filename, 'a') as chf:
                    log.debug('Adding some custom entries to /etc/caasp/hosts...')
                    chf.write('10.10.23.5     foo.server.com\n')
                    chf.write('10.10.23.8     bar.server.com\n')

                changes = self._generate(etc_hosts.name, caasp_etc_hosts_filename)

                etc_hosts.seek(0)
                new_contents = etc_hosts.read()
                log_block('/etc/hosts', new_contents,
                          description='/etc/hosts contents AFTER adding some custom entries in /etc/caasp/hosts')
                log_block('changes', changes, description='two new extries should have been added')

                # check some entries are still there
                new_etc_hosts_contents = OrderedDict()
                caasp_hosts._load_hosts_file(new_etc_hosts_contents,
                                             etc_hosts.name)

                check_entry('10.10.23.5', ['foo.server.com'])
                check_entry('10.10.23.8', ['bar.server.com'])

                # repeat previous checks
                check_entry('10.10.10.1', ['admin',
                                           'some-other-name-for-admin'])
                check_entry('127.0.0.1', ['api', 'api.infra.caasp.local',
                                          EXTERNAL_MASTER_NAME,
                                          'localhost',
                                          'master0', 'master0.infra.caasp.local'])
                check_entry('10.10.10.9', ['custom-name'])
                for ip in ['10.10.9.1', '10.10.9.2', '10.10.9.3', '10.10.9.4']:
                    self.assertNotIn(ip, new_etc_hosts_contents)

            finally:
                # some cleanups
                try:
                    os.unlink(caasp_etc_hosts_filename)
                except Exception as e:
                    log.error('could not remove %s: %s', caasp_etc_hosts_filename, e)


if __name__ == '__main__':
    import sys
    sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))

    # be more verbose when running this test directly from command line
    format = '%(asctime)-15s %(message)s'
    logging.basicConfig(format=format, stream=sys.stderr)
    unittest.main()
