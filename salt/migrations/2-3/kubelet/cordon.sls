include:
  - kubectl-config

cordon-old-kubelet-name:
  cmd.run:
    - name: |
        kubectl --request-timeout=1m --kubeconfig={{ pillar['paths']['kubeconfig'] }} cordon {{ grains['machine_id'] + "." + pillar['internal_infra_domain'] }}
    - check_cmd:
      - /bin/true
    - onlyif:
      - kubectl --request-timeout=1m --kubeconfig={{ pillar['paths']['kubeconfig'] }} get node {{ grains['machine_id'] + "." + pillar['internal_infra_domain'] }}
    - require:
      - file: {{ pillar['paths']['kubeconfig'] }}
