# the CIDR for cluster IPs (internal IPs for Pods)
cluster_cidr:     '172.20.0.0/16'

# the CIDR for services (virtual IPs for services)
services_cidr:    '172.21.0.0/16'

# the API service IP (must be inside the 'services_cidr')
api_cluster_ip:   '172.21.0.1'

# port for listening for SSL connections
api_ssl_port:     '6443'

# certificates
# some of these values MUST match the values ussed when generating the kube-ca.*
ca_name:          'kube-ca'
ca_org:           'SUSE'
admin_email:      'admin@kubernetes'

# user and group for running services and some other stuff...
kube_user:        'kube'
kube_group:       'kube'
