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

{%- set masters = salt.saltutil.runner('mine.get', tgt='G@roles:kube-master', fun='network.ip_addrs', tgt_type='compound') %}
{%- for master_id in masters.keys() %}

{{ master_id }}-stop-services:
  salt.state:
    - tgt: {{ master_id }}
    - sls:
      - kube-apiserver.stop
      - kube-controller-manager.stop
      - kube-scheduler.stop
      - etcd.stop

{% endfor %}

{%- set workers = salt.saltutil.runner('mine.get', tgt='G@roles:kube-minion', fun='network.ip_addrs', tgt_type='compound') %}
{%- for worker_id, ip in workers.items() %}

{{ worker_id }}-stop-services:
  salt.state:
    - tgt: {{ worker_id }}
    - sls:
      - kubelet.stop
      - kube-proxy.stop
      - etcd.stop

{% endfor %}

{%- for master_id in masters.keys() %}

{{ master_id }}-backup-etcd:
  salt.function:
    - tgt: {{ master_id }}
    - name: cmd.run
    - arg:
      - mkdir /tmp/backup; btrfs subvolume snapshot /var/lib/etcd /tmp/backup/etcd

{{ master_id }}-migrate-etcd:
  salt.function:
    - tgt: {{ master_id }}
    - name: cmd.run
    - arg:
      - if ! [ -d /var/lib/etcd/proxy ]; then set -a; source /etc/sysconfig/etcdctl; env ETCDCTL_API=3 etcdctl migrate --data-dir=/var/lib/etcd; fi
    - require:
      - salt: {{ master_id }}-backup-etcd

{% endfor %}

{%- for worker_id, ip in workers.items() %}

{{ worker_id }}-backup-etcd:
  salt.function:
    - tgt: {{ worker_id }}
    - name: cmd.run
    - arg:
      - mkdir /tmp/backup; btrfs subvolume snapshot /var/lib/etcd /tmp/backup/etcd

{{ worker_id }}-migrate-etcd:
  salt.function:
    - tgt: {{ worker_id }}
    - name: cmd.run
    - arg:
      - if ! [ -d /var/lib/etcd/proxy ]; then set -a; source /etc/sysconfig/etcdctl; env ETCDCTL_API=3 etcdctl migrate --data-dir=/var/lib/etcd; fi
    - require:
      - salt: {{ worker_id }}-backup-etcd

{% endfor %}

create-etcd-pillar:
  salt.state:
    - tgt: 'roles:admin'
    - tgt_type: grain
    - sls:
      - etcd.migrate

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
