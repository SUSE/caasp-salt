/etc/haproxy/haproxy.cfg:
  file.managed:
    - source: salt://haproxy/haproxy.cfg.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: True
    - dir_mode: 755

haproxy:
  file.managed:
    - name: /etc/kubernetes/manifests/haproxy.yaml
    - source: salt://haproxy/haproxy.manifest
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: True
    - dir_mode: 755
  caasp_retriable.retry:
    - name: iptables-haproxy
{% if "kube-master" in salt['grains.get']('roles', []) %}
    - target: iptables.append
{% else %}
    - target: iptables.delete
{% endif %}
    - retry:
        attempts: 2
    - table:      filter
    - family:     ipv4
    - chain:      INPUT
    - jump:       ACCEPT
    - match:      state
    - connstate:  NEW
    - dports:
      - {{ pillar['api']['ssl_port'] }}
    - proto:      tcp

# Send a HUP to haproxy when the config changes
# TODO: There should be a better way to handle this, but currently, there is not. See
# kubernetes/kubernetes#24957
haproxy_restart:
  cmd.run:
    - name: |-
        haproxy_id=$(docker ps | grep -E "k8s_haproxy.*\.{{ pillar['internal_infra_domain'] | replace(".", "\.") }}_kube-system_" | awk '{print $1}')
        if [ -n "$haproxy_id" ]; then
            docker kill -s HUP $haproxy_id
        fi
    - onchanges:
      - file: /etc/haproxy/haproxy.cfg
