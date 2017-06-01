# actions to run when a host changes/gets/losses connectivity

# update all the /etc/hosts in the cluster
update_etc_hosts:
  runner.state.orchestrate:
    - mods: orch.update-etc-hosts

