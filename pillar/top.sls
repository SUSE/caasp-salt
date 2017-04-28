base:
  '*':
    - params
    - args
    - vars
    - certificates
    - ip_addrs
    - fqdn
    - kubelet
  'G@roles:kube-master':
    - kube-master
