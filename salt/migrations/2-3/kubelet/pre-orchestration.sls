# invoked by the "update" orchestration right
# before starting the real orchestration updating
# and rebooting machines

include:
 - kubectl-config

# Migrates critical data from the old K8S node, to a new one with updated names
/tmp/kubelet-update-pre-orchestration.sh:
  file.managed:
    - source: salt://migrations/2-3/kubelet/kubelet-update-pre-orchestration.sh
    - mode: 0755
  cmd.run:
{% if "kube-master" in salt['grains.get']('roles', []) %}
    - name: /tmp/kubelet-update-pre-orchestration.sh {{ grains['machine_id'] + "." + pillar['internal_infra_domain'] }} {{ grains['nodename'] }} master
{% else %}
    - name: /tmp/kubelet-update-pre-orchestration.sh {{ grains['machine_id'] + "." + pillar['internal_infra_domain'] }} {{ grains['nodename'] }} worker
{% endif %}
    - stateful: True
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - {{ pillar['paths']['kubeconfig'] }}
