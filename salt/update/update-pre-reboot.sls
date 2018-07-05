bypass-haproxy:
  module.run:
    - name: state.apply
    - mods:
        - haproxy.update-pre-reboot
    - kwargs:
        pillar:
          forward_to:
            ip: {{ pillar['forward_to']['ip'] }}

# After bypassing haproxy with new iptables rules we need to restart the kubelet
# service.
restart-kubelet:
  module.run:
    - name: state.apply
    - mods:
        - kubelet.restart
    - require:
        - bypass-haproxy

# Wait for the kubelet to be healthy.
kubelet-health-check:
  caasp_retriable.retry:
    - target:     caasp_http.wait_for_successful_query
    - name:       http://localhost:10248/healthz
    - wait_for:   300
    - retry:
        attempts: 3
    - status:     200
    - opts:
        http_request_timeout: 30
    - require:
        - restart-kubelet
