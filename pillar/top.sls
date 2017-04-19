base:
  '*':
    - params
    - vars
    - certificates
    - ip_addrs
    - fqdn
  'G@roles:kube-master':
    - kube-master
  'G@roles:kube-minion':
    - kube-minion
