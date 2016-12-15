# the flannel backend ('udp', 'vxlan', 'host-gw', etc)
flannel_backend:  'host-gw'

# the CIDR for cluster IPs (internal IPs for Pods)
cluster_cidr:     '172.20.0.0/16'

# the CIDR for services (virtual IPs for services)
services_cidr:    '172.21.0.0/16'

# the API service IP (must be inside the 'services_cidr')
api_cluster_ip:   '172.21.0.1'

# port for listening for SSL connections
api_ssl_port:     '6443'

# DNS service IP and some other stuff (must be inside the 'services_cidr')
dns_cluster_ip:   '172.21.0.2'
dns_domain:       'cluster.local'
dns_replicas:     '1'

# user and group for running services and some other stuff...
kube_user:        'kube'
kube_group:       'kube'

# use a docker registry mirror (it must be a http service)
# docker_registry_mirror: 'mymirror.com:5000'
