mine_update:
  salt.function:
    - name: mine.update
    - tgt: '*'

refresh_pillar:
  salt.function:
    - name: saltutil.refresh_pillar
    - tgt: '*'

ca_setup:
  salt.state:
    - tgt: 'roles:ca'
    - tgt_type: grain
    - highstate: True
    - require:
      - salt: mine_update
      - salt: refresh_pillar

etcd_discovery_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - sls:
      - repositories
      - etcd-discovery
    - require:
      - salt: ca_setup

etcd_proxy_setup:
  salt.state:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - sls:
      - repositories
      - etcd-proxy
    - concurrent: True
    - require:
      - salt: etcd_discovery_setup

kube_master_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - highstate: True
    - require:
      - salt: etcd_proxy_setup

kube_minion_setup:
  salt.state:
    - tgt: 'roles:kube-minion'
    - tgt_type: grain
    - highstate: True
    - concurrent: True
    - require:
      - salt: kube_master_setup

kube_haproxy_setup:
  salt.state:
    - tgt: 'roles:haproxy'
    - tgt_type: grain
    - highstate: True
    - require:
      - salt: kube_master_setup

kube_nfs_setup:
  salt.state:
    - tgt: 'roles:nfs'
    - tgt_type: grain
    - highstate: True
