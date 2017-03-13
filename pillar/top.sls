base:
  '*':
    - params
    - certificates
  'G@roles:etcd':
    - etcd
  'G@roles:kube-master':
    - etcd-proxy
    - kube-master
  'G@roles:kube-minion':
    - etcd-proxy
    - kube-minion
  'G@roles:nfs':
    - nfs
