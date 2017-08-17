# the flannel backend ('udp', 'vxlan', 'host-gw', etc)
flannel:
  image:          'sles12/flannel:1.0.0'
  backend:        'vxlan'   # UDP seems to be near end of life (https://github.com/coreos/flannel/pull/786)
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

# CNI network configuration
cni:
  plugin:         'flannel'
  dirs:
    #bin:          '/opt/cni/bin'
    # TODO: use the standard directory
    bin:          '/var/lib/kubelet/cni/bin'
    conf:         '/etc/cni/net.d'
