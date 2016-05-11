etcd_setup:
  salt.state:
    - tgt: 'roles:etcd'
    - tgt_type: grain
    - highstate: True

kube_master_setup:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - highstate: True
    - require:
      - salt: etcd_setup

kube_minion_setup:
  salt.state:
    - tgt: 'roles:kube-minion'
    - tgt_type: grain
    - highstate: True
    - require:
      - salt: kube_master_setup
