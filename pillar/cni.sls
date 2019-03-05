# the flannel backend ('udp', 'vxlan', 'host-gw', etc)
flannel:
  image:          'registry.suse.com/caasp/v4/flannel:0.9.1'
  backend:        'vxlan'
  port:           '8472'    # UDP port to use for sending encapsulated packets. Defaults to kernel default, currently 8472.
  healthz_port:   '8471'    # TCP port used for flannel healthchecks
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
# cilium configuration
cilium:
  image:          'cilium:1.2.1'

# CNI network configuration
cni:
  plugin:         'flannel'
  dirs:
    # We are not using the standard `/opt/cni/bin` directory as it's not allowed to install files
    # in `/opt` in TW as well as on SLE.
    bin:  '/var/lib/kubelet/cni/bin'
    conf: '/etc/cni/net.d'
