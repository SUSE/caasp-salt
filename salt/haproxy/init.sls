{% if "admin" not in salt['grains.get']('roles', []) %}
include:
  - {{ salt.caasp_cri.cri_salt_state_name() }}
  - kubelet
  - container-feeder
{% endif %}

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
haproxy-restart:
  caasp_cri.stop_container_and_wait:
    - name: haproxy
    - namespace: kube-system
    - timeout: 60
    - onchanges:
      - file: /etc/caasp/haproxy/haproxy.cfg
    - require:
      - service: container-feeder


{% if 'admin' in salt['grains.get']('roles', []) %}
# The admin node is serving the internal API with the pillars. Wait for it to come back
# before going on with the orchestration/highstates.
wait-for-haproxy:
  http.wait_for_successful_query:
    - name:       https://localhost:444/internal-api/v1/pillar.json
    - wait_for:   300
    - status:     401
    - verify_ssl: False
    - onchanges:
      - haproxy-restart
{% endif %}
