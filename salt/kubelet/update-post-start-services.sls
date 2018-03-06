# invoked by the "update" orchestration after starting
# all the services after rebooting

remove-old-node-entry:
  cmd.run:
    - name: kubectl --request-timeout=1m delete node {{ grains['machine_id'] + "." + pillar['internal_infra_domain'] }}
    - check_cmd:
      - /bin/true
    - onlyif:
      - kubectl --request-timeout=1m get node {{ grains['machine_id'] + "." + pillar['internal_infra_domain'] }}
