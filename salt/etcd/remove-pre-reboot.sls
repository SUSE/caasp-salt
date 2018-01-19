
# cleanup all the things we have created for etcd

/etc/sysconfig/etcd:
  file.absent

/etc/sysconfig/etcdctl:
  file.absent

/etc/systemd/system/etcd.service.d/etcd.conf:
  file.absent

etcd-user-removal:
  user.absent:
    - name: etcd

etcd-group-removal:
  group.absent:
    - name: etcd

etcd-wipe-var-lib:
  cmd.run:
    - name: rm -rf /var/lib/etcd/*
