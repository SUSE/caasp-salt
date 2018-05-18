base:
  'roles:ca':
    - match: grain
    - ca
  'roles:(admin|kube-master|kube-minion|etcd)':
    - match: grain_pcre
    - ca-cert
    - cri
    - container-feeder
    {% if not salt.caasp_nodes.is_admin_node() %}
      # the admin node uses docker as CRI, requiring its state
      # will cause the docker daemon to be restarted, which will
      # lead to the premature termination of the orchestration.
      # Hence let's not require docker on the admin node.
      # This is not a big deal because the admin node has already
      # working since the boot time.
    - {{ salt['pillar.get']('cri:chosen', 'docker') }}
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
    - motd
    - users
    - cert
    - kubelet
    - kube-proxy
    - cni/cilium
