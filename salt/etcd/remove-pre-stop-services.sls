
# this node is being removed from the cluster,
# but etcd is still running:
# we explicitly remove the node from the etcd cluster,
# so it is not considered a node suffering some
# transient failure...
etcd-remove-member:
  caasp_etcd.member_remove
  # NOTE: we are not requiring /etc/hosts or the certificates
  #       because we are assuming this node was on high state
