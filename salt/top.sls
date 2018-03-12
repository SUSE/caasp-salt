base:
  'roles:ca':
    - match: grain
    - ca
  'roles:(admin|kube-master|kube-minion|etcd)':
    - match: grain_pcre
    - ca-cert
    - cri-common
    - container-feeder
    {% if 'admin' not in grains.get('roles', []) %}
    - {{ salt.caasp_cri.cri_salt_state_name() }}
    {% endif %}
    - swap
    - etc-hosts
    - proxy
    - rebootmgr
    - transactional-update
    - haproxy
    - kubectl-config
  'roles:admin':
    - match: grain
    - velum
    - ldap
  'roles:etcd':
    - match: grain
    - etcd
  'roles:kube-master':
    - match: grain
    - kube-apiserver
    - kube-controller-manager
    - kube-scheduler
  'roles:(kube-master|kube-minion|etcd)':
    - match: grain_pcre
    - repositories
    - motd
    - users
    - cert
    - kubelet
    - kube-proxy
