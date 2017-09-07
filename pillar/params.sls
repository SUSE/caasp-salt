# the CIDR for cluster IPs (internal IPs for Pods)
cluster_cidr:     '172.16.0.0/13'

# The min and max subnet, and length for node allocations.
# The defaults allow for 510 pod IPs per host (/23) allowing
# for a maximum of 1024 hosts.
cluster_cidr_min: '172.16.0.0'
cluster_cidr_max: '172.23.255.255'
cluster_cidr_len: 23

# the CIDR for services (virtual IPs for services)
services_cidr:    '172.24.0.0/16'

# the cluster domain name used for internal infrastructure host <-> host  communication
internal_infra_domain: 'infra.caasp.local'
ldap_internal_infra_domain: 'dc=infra,dc=caasp,dc=local'

api:
  # the API service IP (must be inside the 'services_cidr')
  cluster_ip:     '172.24.0.1'
  # port for listening for SSL connections (load balancer)
  ssl_port:       '6443'
  # port for listening for SSL connections (kube-api)
  int_ssl_port:   '6444'
  # etcd storage backend version for cluster
  etcd_version:   'etcd3'


# DNS service IP and some other stuff (must be inside the 'services_cidr')
dns:
  cluster_ip:     '172.24.0.2'
  domain:         'cluster.local'
  replicas:       '1'

# user and group for running services and some other stuff...
kube_user:        'kube'
kube_group:       'kube'

# set log level for kubernetes services
# 0 - Generally useful for this to ALWAYS be visible to an operator.
# 1 - A reasonable default log level if you don't want verbosity.
# 2 - Useful steady state information about the service and important log 
#     messages that may correlate to significant changes in the system. 
#     This is the recommended default log level for most systems.
# 3 - Extended information about changes.
# 4 - Debug level verbosity.
# 6 - Display requested resources.
# 7 - Display HTTP request headers.
# 8 - Display HTTP request contents.
kube_log_level:   '2'

# install the addons (ie, DNS)
addons:
  dns:    'true'
  tiller: 'false'

ssl:
  enabled:        true
  ca_dir:         '/etc/pki/trust/anchors'
  ca_file:        '/etc/pki/trust/anchors/SUSE_CaaSP_CA.crt'
  crt_file:       '/etc/pki/minion.crt'
  key_file:       '/etc/pki/minion.key'

  crt_dir:        '/etc/pki'
  key_dir:        '/etc/pki'

  kube_apiserver_key: '/etc/pki/kube-apiserver.key'
  kube_apiserver_crt: '/etc/pki/kube-apiserver.crt'

  kube_scheduler_key: '/etc/pki/kube-scheduler.key'
  kube_scheduler_crt: '/etc/pki/kube-scheduler.crt'

  kube_controller_mgr_key: '/etc/pki/kube-controller-mgr.key'
  kube_controller_mgr_crt: '/etc/pki/kube-controller-mgr.crt'
  
  kubelet_key: '/etc/pki/kubelet.key'
  kubelet_crt: '/etc/pki/kubelet.crt'

  kube_proxy_key: '/etc/pki/kube-proxy.key'
  kube_proxy_crt: '/etc/pki/kube-proxy.crt'

paths:
  var_kubelet:    '/var/lib/kubelet'
  kubeconfig:     '/var/lib/kubelet/kubeconfig'

  kube_scheduler_config: '/var/lib/kubelet/kube-scheduler-config'

  kube_controller_mgr_config: '/var/lib/kubelet/kube-controller-mgr-config'

  kubelet_config: '/var/lib/kubelet/kubelet-config'

  kube_proxy_config: '/var/lib/kubelet/kube-proxy-config'

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
# set log level for etcd service
# potential log levels are:
# [ CRITICAL, ERROR, WARNING NOTICE, INFO, DEBUG ]
  log_level:      'WARNING'

# the flannel backend ('udp', 'vxlan', 'host-gw', etc)
flannel:
  backend:        'udp'
  etcd_key:       '/flannel/network'
  iface:          'eth0'
# log level for flanneld service
# 0 - Generally useful for this to ALWAYS be visible to an operator.
# 1 - A reasonable default log level if you don't want verbosity.
# 2 - Useful steady state information about the service and important log 
#     messages that may correlate to significant changes in the system. 
#     This is the recommended default log level for most systems.
# 3 - Extended information about changes.
# 4 - Debug level verbosity.
# 6 - Display requested resources.
# 7 - Display HTTP request headers.
# 8 - Display HTTP request contents.
  log_level:      '2'

kubelet:
  port:           '10250'

proxy:
  http:           ''
  https:          ''
  no_proxy:       ''
  systemwide:     'true'

# Kubernetes is designed to work with different Clouds such as Google Compute Engine (GCE), 
# Amazon Web Services (AWS), and OpenStack; therefore, different load balancers need to be created 
# on the particular Cloud for the services. This is done through a plugin for each Cloud.
# https://github.com/kubernetes/kubernetes/blob/release-1.7/pkg/cloudprovider/README.md
cloud:
  provider:     ''
  openstack:
    auth_url:       ''
    domain:         ''
    project:        ''
    region:         ''
    username:       ''
    password:       ''
    # OpenStack subnet UUID for the CaasP private network
    subnet:         ''
    # OpenStack load balancer monitor max retries
    lb_mon_retries: '3'
    # OpenStack Cinder Block Storage API version
    bs_version:     'v2'

# Configuration for the reboot manager (https://github.com/SUSE/rebootmgr).
# notes:
# - The default group for rebootmgr is "default", so we are simply taking
#   rebootmgr's default here.
# - `directory` contains the base directory of the configuration. In order to
#   use it we have to append the name of the group as another directory.
reboot:
  group:          'default'
  directory:      'opensuse.org/rebootmgr/locks'

transactional-update:
  timer:
    on_calendar: 'daily' # See https://www.freedesktop.org/software/systemd/man/systemd.time.html#Calendar%20Events for syntax

dex:
  node_port: 32000

# configuration parameters for interacting with LDAP via Dex
# these get filled in by velum during bootstrap. they're listed
# here for documentation purposes.
ldap:
  host: ''
  port: 0
  bind_dn: ''
  bind_pw: ''
  domain: ''
  group_dn: ''
  people_dn: ''
  base_dn: ''
  admin_group_dn: ''
  admin_group_name: ''
  tls_method: ''
  mail_attribute: ''
