base:
  '*':
    - repositories
{% if pillar.get('avahi', '').lower() == 'true' %}
    - avahi
{% endif %}
    - motd
    - users
{% if salt['pillar.get']('infrastructure', 'libvirt') == 'cloud' %}
    - hosts
{% endif %}
  '*salt*':
    - salt-master
  'roles:etcd':
    - match: grain
    - etcd
  'roles:kube-master':
    - match: grain
    - certs
    - kubernetes-master
  'roles:kube-minion':
    - match: grain
    - certs
    - kubernetes-minion
    - docker
    - flannel
  'roles:nfs':
    - match: grain
    - nfs-server
  'roles:haproxy':
    - match: grain
    - confd
    - haproxy
