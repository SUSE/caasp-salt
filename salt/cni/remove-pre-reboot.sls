# cleanup all the things we have created

/etc/kubernetes/addons/kube-flannel-rbac.yaml:
  file.absent

/etc/kubernetes/addons/kube-flannel.yaml:
  file.absent
