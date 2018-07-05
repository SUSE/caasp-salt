# invoked by the "update" orchestration right
# before starting the real orchestration updating
# and rebooting machines

include:
 - kubectl-config

# try to save the flannel subnet in the .spec.podCIDR (if not assigned yet)
/tmp/cni-update-pre-orchestration.sh:
  file.managed:
    - source: salt://migrations/2-3/cni/cni-update-pre-orchestration.sh
    - mode: 0755
  cmd.run:
    - name: /tmp/cni-update-pre-orchestration.sh {{ grains['machine_id'] + "." + pillar['internal_infra_domain'] }} {{ salt.caasp_net.get_primary_ip() }} {{ salt.caasp_pillar.get('flannel:backend', 'vxlan') }}
    - stateful: True
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - {{ pillar['paths']['kubeconfig'] }}
