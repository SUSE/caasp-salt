include:
  - kubectl-config

drain-old-kubelet-name:
  cmd.run:
    - name: |
        kubectl --request-timeout=1m --kubeconfig={{ pillar['paths']['kubeconfig'] }} drain {{ grains['machine_id'] + "." + pillar['internal_infra_domain'] }} --force --delete-local-data=true --ignore-daemonsets
    - check_cmd:
      - /bin/true
    - onlyif:
      - kubectl --request-timeout=1m --kubeconfig={{ pillar['paths']['kubeconfig'] }} get node {{ grains['machine_id'] + "." + pillar['internal_infra_domain'] }}
    - require:
      - file: {{ pillar['paths']['kubeconfig'] }}
