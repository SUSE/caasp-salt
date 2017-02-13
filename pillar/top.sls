base:
  '*':
    - params
    - vars
    - certificates
  'G@roles:etcd':
    - etcd
  'G@roles:kube-master':
    - etcd-proxy
    - kube-master
    - sle
  'G@roles:kube-minion':
    - etcd-proxy
    - kube-minion
    - sle
  'G@roles:nfs':
    - nfs
