# invoked by the "update" orchestration right
# before rebooting a machine

uninstall-flannel:
  # we cannot remove the flannel package, so we can only
  # make sure that the service is disabled
  service.disabled:
    - name: flanneld
