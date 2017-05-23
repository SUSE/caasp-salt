import os
# Import python libs
import logging

# Import third party libs
try:
    import etcd
    HAS_LIBS = True
except ImportError:
    HAS_LIBS = False

# Set up logging
log = logging.getLogger(__name__)

def etcd_info():
  # TODO: Certificates configuration should be 
  # provided in pillar profile config
  ca_cert = "/etc/pki/trust/anchors/SUSE_CaaSP_CA.crt"
  cli_cert = "/etc/pki/minion.crt"
  cli_key = "/etc/pki/minion.key"

  client_args = {}
  if os.path.isfile(ca_cert): client_args['ca_cert'] = ca_cert
  if os.path.isfile(cli_key) and os.path.isfile(cli_cert):
    client_args.update({'cert': (cli_cert, cli_key),  'protocol': 'https'})

  etcd_info = {}
  etcd_info['members_all'] = []
  etcd_info['member_type'] = ""

  if HAS_LIBS:
    etcd_info['etcd_module'] = "available"
    client = etcd.Client(host='localhost', port=2379, **client_args)
  else:
    etcd_info['etcd_module'] = "missing"
    log.error("etcd: unable to import python-etcd")
    return {'etcd_info': etcd_info}

  try:
    with open("/etc/machine-id", "r") as machine_file:
      machine_id = machine_file.read().rstrip()
    machine_file.close()
  except IOError as e:
    log.error("etcd: problem with /etc/machine-id ({0}): {1}".format(e.errno, e.strerror))
    return {'etcd_info': etcd_info}

  etcd_info['member_type'] = "proxy"

  etcd_members = client.members
  for index in etcd_members:
    member = etcd_members[index]
    etcd_info['members_all'].append(member['name'])
    if machine_id == member['name']:
      etcd_info['member_type'] = "member"
      etcd_info['member_id'] = member['id']

  if machine_id == client.leader['name']:
    etcd_info['member_type'] = "leader"

  return {'etcd_info': etcd_info}
