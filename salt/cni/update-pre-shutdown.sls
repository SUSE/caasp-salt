# invoked by the "update" orchestration right
# before shutting down all the k8s services

include:
 - kubectl-config

{% from '_macros/network.jinja' import get_primary_ip with context %}

# try to save the flannel subnet in the .spec.podCIDR (if not assigned yet)
/tmp/update-pre-shutdown.sh:
  file.managed:
    - source: salt://cni/update-pre-shutdown.sh
    - mode: 0755
  cmd.run:
    - name: /tmp/update-pre-shutdown.sh {{ grains['caasp_fqdn'] }} {{ get_primary_ip() }} {{ salt.caasp_pillar.get('flannel:backend', 'vxlan') }}
    - stateful: True
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - {{ pillar['paths']['kubeconfig'] }}
