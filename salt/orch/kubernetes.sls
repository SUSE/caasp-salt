hostname_setup:
  salt.state:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - concurrent: True
    - sls:
      - hostname

update_pillar:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_pillar
    - require:
      - salt: hostname_setup

update_mine:
  salt.function:
    - tgt: '*'
    - name: mine.update
    - require:
      - salt: update_pillar

update_modules:
  salt.function:
    - name: saltutil.sync_modules
    - tgt: '*'
    - kwarg:
        refresh: True

etc_hosts_setup:
  salt.state:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - concurrent: True
    - sls:
      - etc-hosts
    - require:
      - salt: update_mine

ca_setup:
  salt.state:
    - tgt: 'roles:ca'
    - tgt_type: grain
    - highstate: True
    - require:
      - salt: etc_hosts_setup
      - salt: update_mine

kubernetes_master_cert_generation:
  salt.state:
    - tgt: ca
    - highstate: False
    - concurrent: True
    - sls:
      - kubernetes-master-cert-generation
    - require:
      - salt: ca_setup

etcd_cert_generation:
  salt.state:
    - tgt: ca
    - highstate: False
    - concurrent: True
    - sls:
      - etcd-cert-generation
    - require:
      - salt: ca_setup

etcd_discovery_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - sls:
      - etcd-discovery
    - require:
      - salt: ca_setup
      - salt: update_modules

etcd_nodes_setup:
  salt.state:
    - tgt: 'roles:etcd'
    - tgt_type: grain
    - highstate: True
    - concurrent: True
    - require:
      - salt: etcd_discovery_setup
      - salt: etcd_cert_generation

etcd_proxy_setup:
  salt.state:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - sls:
      - etcd-proxy
    - concurrent: True
    - require:
      - salt: etcd_discovery_setup
      - salt: etcd_cert_generation

flannel_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - concurrent: True
    - sls:
      - flannel-setup
    - require:
      - salt: etcd_proxy_setup

kube_master_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - highstate: True
    - concurrent: True
    - require:
      - salt: flannel_setup
      - salt: kubernetes_master_cert_generation

kube_minion_setup:
  salt.state:
    - tgt: 'roles:kube-minion'
    - tgt_type: grain
    - highstate: True
    - concurrent: True
    - require:
      - salt: flannel_setup
      - salt: kube_master_setup

reboot_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - sls:
      - reboot
    - require:
      - salt: kube_master_setup
