# Stop and disable the Kubernetes minion daemons, ensuring pods have been drained
# and the node is marked as unschedulable.

include:
  - kubectl-config

{% set should_uncordon = salt['cmd.run']("kubectl --request-timeout=1m --kubeconfig=" + pillar['paths']['kubeconfig'] + " get nodes " + grains['nodename'] + " -o=jsonpath='{.spec.unschedulable}' 2>/dev/null") != "true" %}
{% set node_removal_in_progress = salt['grains.get']('node_removal_in_progress', False) %}

drain-kubelet:
  cmd.run:
    - name: |
        # give some time to drain the node, if it times out continue to ensure the update will continue
        # this can cause downtime of applications, so ideally an application is drainable within the drain-timeout
        # bsc#1116049
        kubectl --request-timeout=1m --kubeconfig={{ pillar['paths']['kubeconfig'] }} drain {{ grains['nodename'] }} --force --delete-local-data=true --ignore-daemonsets --timeout={{ pillar['kubelet']['drain-timeout'] }}s
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
