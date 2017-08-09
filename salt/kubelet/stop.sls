# Stop and disable the Kubernetes minion daemons, ensuring pods have been drained
# and the node is marked as unschedulable.

# If this fails we should ignore it and proceed anyway as Kubernetes will recover
drain-kubelet:
  cmd.run:
    - name: |
        kubectl drain {{ grains['caasp_fqdn'] }} --ignore-daemonsets --grace-period=300 --timeout=340s
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - check_cmd:
      - /bin/true

kubelet:
  service.dead:
    - enable: False
    - require:
      - cmd: drain-kubelet
