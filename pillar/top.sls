base:
  '*':
    - params
    - vars
    - certificates
    - ip_addrs
    - fqdn
  'G@roles:kube-master or ca':
    - kube-master
  'G@roles:kube-minion':
    - kube-minion
