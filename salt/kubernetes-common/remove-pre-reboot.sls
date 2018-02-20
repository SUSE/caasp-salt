# cleanup all the things we have created

/etc/kubernetes/config:
  file.absent

/etc/kubernetes/openstack-config:
  file.absent

/var/lib/kubernetes:
  file.absent
