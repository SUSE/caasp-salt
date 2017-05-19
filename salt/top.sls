base:
  'roles:ca':
    - match: grain
    - ca
  'roles:kube-(master|minion)':
    - match: grain_pcre
    - repositories
    - motd
    - users
    - hostname
    - etc-hosts
    - cert
    - etcd-proxy
    - flannel
    - docker
    - haproxy
    - kube-proxy
    - kubelet
    - kubeconfig
  'roles:kube-master':
    - match: grain
    - kubernetes-master
    - kube-apiserver
    - kube-controller-manager
    - kube-scheduler
  'roles:kube-minion':
    - match: grain
    - kubernetes-minion
