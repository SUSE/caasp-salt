# Stop and disable the Kubernetes minion daemons, ensuring pods have been drained
# and the node is marked as unschedulable.

include:
  - kubectl-config

{% set should_uncordon = salt['cmd.run']("kubectl --kubeconfig=" + pillar['paths']['kubeconfig'] + " get nodes " + grains['nodename'] + " -o=jsonpath='{.spec.unschedulable}' 2>/dev/null") != "true" %}
{% set node_removal_in_progress = salt['grains.get']('node_removal_in_progress', False) %}

# If this fails we should ignore it and proceed anyway as Kubernetes will recover
drain-kubelet:
  cmd.run:
    - name: |
        kubectl --kubeconfig={{ pillar['paths']['kubeconfig'] }} drain {{ grains['nodename'] }} --force --delete-local-data=true --ignore-daemonsets --grace-period=300 --timeout=340s
    - check_cmd:
      - /bin/true
    - require:
      - file: {{ pillar['paths']['kubeconfig'] }}
  {%- if not node_removal_in_progress %}
  grains.present:
    - name: kubelet:should_uncordon
    - value: {{ should_uncordon }}
    - force: True
  {%- endif %}

{%- if node_removal_in_progress %}

# we must run the `delete node` when haproxy is still running.
#   * in pre-stop-services, we have not cordoned the node yet
#   * in pre-reboot, haproxy has been stopped
# so we have to do it here...

delete-node-from-kubernetes:
  cmd.run:
    - name: |-
        kubectl --kubeconfig={{ pillar['paths']['kubeconfig'] }} delete node {{ grains['nodename'] }}
    - require:
      - file: {{ pillar['paths']['kubeconfig'] }}
      - drain-kubelet

{%- endif %}

kubelet:
  service.dead:
    - enable: False
    - require:
      - cmd: drain-kubelet
  caasp_retriable.retry:
    - name: iptables-kubelet
    - target: iptables.append
    - retry:
        attempts: 2
    - table:     filter
    - family:    ipv4
    - chain:     INPUT
    - jump:      ACCEPT
    - match:     state
    - connstate: NEW
    - dports:
      - {{ pillar['kubelet']['port'] }}
    - proto:     tcp
