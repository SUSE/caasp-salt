# invoked by the "update" orchestration after starting
# all the services after rebooting

# CNI does not use the docker0 bridge: remote it
remove-docker-iface:
  cmd.run:
    - name: ip link delete docker0
    - check_cmd:
      - /bin/true
    # TODO: maybe we should restart dockerd...
