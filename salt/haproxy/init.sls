/etc/caasp/haproxy:
  file.directory:
    - name: /etc/caasp/haproxy
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True

/etc/caasp/haproxy/haproxy.cfg:
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
    - source: salt://haproxy/haproxy.yaml.jinja
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

# Send a SIGTERM to haproxy when the config changes
# TODO: There should be a better way to handle this, but currently, there is not. See
# kubernetes/kubernetes#24957
haproxy_restart:
  cmd.run:
    - name: |-
        haproxy_id=$(docker ps | grep -E "k8s_haproxy.*_kube-system_" | awk '{print $1}')
        if [ -n "$haproxy_id" ]; then
            # Don't allow this state to fail if docker kill fails, this avoids
            # a race condition between `docker ps` and `docker kill`
            docker kill $haproxy_id || :
        fi
    - onchanges:
      - file: /etc/caasp/haproxy/haproxy.cfg

{% if "admin" in salt['grains.get']('roles', []) %}
# The admin node is serving the internal API with the pillars. Wait for it to come back
# before going on with the orchestration/highstates.
wait_for_haproxy:
  cmd.run:
    - name: |-
        until $(docker ps | grep -E "k8s_haproxy.*_kube-system_" &> /dev/null); do
            sleep 1
        done
{% endif %}
