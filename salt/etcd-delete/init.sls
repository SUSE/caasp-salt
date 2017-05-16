{% set etcd_member_id = salt['grains.get']('etcd_info:member_id', '') %}

etcd_member_remove:
  cmd.run:
    - name: etcdctl member remove {{ etcd_member_id }}
    - check_cmd:
      - /bin/true
