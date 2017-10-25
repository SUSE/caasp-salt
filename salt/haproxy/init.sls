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
{% if "kube-master" in salt['grains.get']('roles', []) %}
  iptables.append:
{% else %}
  iptables.delete:
{% endif %}
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
    - name: docker kill -s HUP {{ salt['grains.get']('containers:haproxy', '') }}
    - onlyif: test -n "{{ salt['grains.get']('containers:haproxy', '') }}"
    - onchanges:
      - file: /etc/haproxy/haproxy.cfg
