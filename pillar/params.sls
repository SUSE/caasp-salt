# the CIDR for cluster IPs (internal IPs for Pods)
cluster_cidr:     '172.20.0.0/16'

# the cluster domain name used for internal infrastructure host <-> host  communication
internal_infra_domain: 'infra.caasp.local'

# the CIDR for services (virtual IPs for services)
services_cidr:    '172.21.0.0/16'

api:
  # the API service IP (must be inside the 'services_cidr')
  cluster_ip:     '172.21.0.1'
  # port for listening for SSL connections
  ssl_port:       '6443'

# DNS service IP and some other stuff (must be inside the 'services_cidr')
dns:
  cluster_ip:     '172.21.0.2'
  domain:         'cluster.local'
  replicas:       '1'

# user and group for running services and some other stuff...
kube_user:        'kube'
kube_group:       'kube'

# install the addons (ie, DNS)
addons:           'false'

paths:
  ca_dir:         '/etc/pki/trust/anchors'
  ca_filename:    'SUSE_CaaSP_CA.crt'
  var_kubelet:    '/var/lib/kubelet'
  kubeconfig:     '/var/lib/kubelet/kubeconfig'

# etcd details
# notes:
# - the token must be shared between all the machines in the cluster
# - the discovery id is also unique for all the machines in the
#   cluster (in fact, it can be the same as the token)
# - if masters is null, we will determine the number of etcd members
#   based on the number of nodes with the kube-master role applied
# - For an etcd cluster to be effective, the number of cluster members
#   must be both odd and reasonably small, for example - 1,3,5 are
#   valid while 2,4,6 are not. In addition, clusters larger than 5 are
#   likely spending more time coordinating amongst themselves than they
#   are serving clients. As such, it's not recommended to use a cluster
#   of 7+ nodes.
etcd:
  masters:        null
  token:          'k8s'
  disco:
    port:         '2379'
    id:           'k8s'

# the flannel backend ('udp', 'vxlan', 'host-gw', etc)
flannel:
  backend:        'udp'
  etcd_key:       '/flannel/network'
  iface:          'eth0'

proxy:
  http:           ''
  https:          ''
  no_proxy:       ''

# Configuration for the reboot manager (https://github.com/SUSE/rebootmgr).
# notes:
# - The default group for rebootmgr is "default", so we are simply taking
#   rebootmgr's default here.
# - `directory` contains the base directory of the configuration. In order to
#   use it we have to append the name of the group as another directory.
reboot:
  group:          'default'
  directory:      'opensuse.org/rebootmgr/locks'
