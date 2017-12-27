# Stop and disable the Kubernetes minion daemons, ensuring pods have been drained
# and the node is marked as unschedulable.

include:
  - kubectl-config

{% set should_uncordon = salt['cmd.run']("kubectl --kubeconfig=" + pillar['paths']['kubeconfig'] + " get nodes " + grains['caasp_fqdn'] + " -o=jsonpath='{.spec.unschedulable}' 2>/dev/null") != "true" %}

# If this fails we should ignore it and proceed anyway as Kubernetes will recover
drain-kubelet:
  cmd.run:
    - name: |
        kubectl drain {{ grains['caasp_fqdn'] }} --ignore-daemonsets --grace-period=300 --timeout=340s
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - check_cmd:
      - /bin/true
    - require:
      - file: {{ pillar['paths']['kubeconfig'] }}
  grains.present:
    - name: kubelet:should_uncordon
    - value: {{ should_uncordon }}
    - force: True

kubelet:
  service.dead:
    - enable: False
    - require:
      - cmd: drain-kubelet
