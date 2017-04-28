base:
  '*':
    - repositories
    - motd
    - users
  'roles:ca':
    - match: grain
    - ca
  'roles:kube-(master|minion)':
    - match: grain_pcre
    - hostname
    - etc-hosts
    - cert
    - etcd-proxy
    - flannel
    - docker
    - haproxy
    - kubelet
    - kubeconfig
  'roles:kube-master':
    - match: grain
    - hosts-master
    - kubernetes-master
    - flannel
    - docker
    - reboot
  'roles:kube-minion':
    - match: grain
    - hosts-minion
    - flannel
    - docker
    - kubernetes-minion
