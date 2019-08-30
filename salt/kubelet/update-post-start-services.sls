# invoked by the "update" orchestration after starting
# all the services after rebooting

include:
  - kubectl-config

{% if salt['grains.get']('kubelet:should_uncordon', false) %}

uncordon-node:
  cmd.run:
    - name: |
        kubectl --request-timeout=1m uncordon {{ grains['nodename'] }}
    - retry:
        attempts: 10
        interval: 3
        until: |
          test "$(kubectl --request-timeout=1m --kubeconfig={{ pillar['paths']['kubeconfig'] }} get nodes {{ grains['nodename'] }} -o=jsonpath='{.spec.unschedulable}' 2>/dev/null)" != "true"
    - require:
      - file: {{ pillar['paths']['kubeconfig'] }}
  grains.absent:
    - name: kubelet:should_uncordon
    - destructive: True
    - require:
      - caasp_cmd: uncordon-node

{% else %}

uncordon-node:
  cmd.run:
    - name: "echo {{ grains['nodename'] }} should not be uncordoned. Skipping."

{% endif %}
