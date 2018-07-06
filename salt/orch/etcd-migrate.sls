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

stop-kubelet:
  salt.state:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - sls:
      - kube-proxy.stop
      - kubelet.stop
    - require:
      - salt: update_mine

stop-kubernetes:
  salt.state:
    - tgt: 'roles:kube-master'
    - tgt_type: grain
    - sls:
      - kube-apiserver.stop
      - kube-controller-manager.stop
      - kube-scheduler.stop
    - require:
      - salt: stop-kubelet

stop-etcd:
  salt.state:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - sls:
      - etcd.stop
    - require:
      - salt: stop-kubernetes

backup-etcd:
  salt.function:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - name: cmd.run
    - arg:
      - if [ -d /var/lib/etcd/member ] && ! [ -d /tmp/backup ]; then mkdir /tmp/backup; btrfs subvolume snapshot /var/lib/etcd /tmp/backup/etcd; fi
    - require:
      - salt: stop-etcd

migrate-etcd:
  salt.function:
    - tgt: 'roles:kube-(master|minion)'
    - tgt_type: grain_pcre
    - name: cmd.run
    - arg:
      - if [ -d /var/lib/etcd/member ]; then set -a; source /etc/sysconfig/etcdctl; env ETCDCTL_API=3 etcdctl migrate --data-dir=/var/lib/etcd; fi
    - require:
      - salt: backup-etcd

create-etcd-pillar:
  salt.state:
    - tgt: 'roles:admin'
    - tgt_type: grain_pcre
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
