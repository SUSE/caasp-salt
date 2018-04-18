# invoked by the "update" orchestration after starting
# all the services after rebooting

# CNI does not use the docker0 bridge: remove it
remove-docker-iface:
  cmd.run:
    - name: ip link delete docker0
    - onlyif: grep -q docker0 /proc/net/dev
    # TODO: maybe we should restart dockerd... Note well: do that only when
    # caasp_cri.cri_name() == 'docker'
