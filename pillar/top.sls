base:
  '*':
    - params
    - vars
    - certificates
  'G@roles:kube-master':
    - etcd-proxy
    - kube-master
  'G@roles:kube-minion':
    - etcd-proxy
    - kube-minion
  'G@roles:nfs':
    - nfs
