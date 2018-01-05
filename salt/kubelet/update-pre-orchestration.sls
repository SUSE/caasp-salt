# invoked by the "update" orchestration right
# before starting the real orchestration updating
# and rebooting machines

include:
 - kubectl-config

# Migrates critical data from the old K8S node, to a new one with updated names
/tmp/kubelet-update-pre-orchestration.sh:
  file.managed:
    - source: salt://kubelet/update-pre-orchestration.sh
    - mode: 0755
  cmd.run:
    - name: /tmp/kubelet-update-pre-orchestration.sh {{ grains['machine_id'] + "." + pillar['internal_infra_domain'] }} {{ grains['nodename'] }}
    - stateful: True
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - {{ pillar['paths']['kubeconfig'] }}
