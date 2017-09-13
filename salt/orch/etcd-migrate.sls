# Generic Updates
update_pillar:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_pillar

update_grains:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_grains

update_mine:
  salt.function:
    - tgt: '*'
    - name: mine.update
    - require:
       - salt: update_pillar
       - salt: update_grains

master-stop-services:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - sls:
      - kube-apiserver.stop
      - kube-controller-manager.stop
      - kube-scheduler.stop
      - etcd.stop
    - require:
       - salt: update_mine

worker-stop-services:
  salt.state:
    - tgt: 'roles:kube-minion'
    - tgt_type: grain
    - sls:
      - kubelet.stop
      - kube-proxy.stop
      - etcd.stop
    - require:
       - salt: master-stop-services

backup-etcd:
  salt.function:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - name: cmd.run
    - arg:
      - mkdir /tmp/backup; btrfs subvolume snapshot /var/lib/etcd /tmp/backup/etcd
    - require:
       - salt: worker-stop-services

migrate-etcd:
  salt.function:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - name: cmd.run
    - arg:
      - if ! [ -d /var/lib/etcd/proxy ]; then set -a; source /etc/sysconfig/etcdctl; env ETCDCTL_API=3 etcdctl migrate --data-dir=/var/lib/etcd; fi
    - require:
      - salt: backup-etcd

create-etcd-pillar:
  salt.state:
    - tgt: 'roles:admin'
    - tgt_type: grain
    - sls:
      - etcd.migrate
    - require:
      - salt: migrate-etcd

refresh-pillars:
  salt.function:
    - tgt: '*'
    - name: saltutil.refresh_pillar
    - require:
      - salt: create-etcd-pillar

start-all-services-again:
  salt.state:
    - tgt: '*'
    - highstate: True
    - require:
      - salt: refresh-pillars
