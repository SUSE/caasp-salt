base:
  '*':
    - params
    - certificates
  'G@roles:etcd':
    - etcd
  'G@roles:kube-master':
    - kube-master
    - sle
  'G@roles:kube-minion':
    - kube-minion
    - sle
  'G@roles:nfs':
    - nfs
