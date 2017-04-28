---
/etc/haproxy/haproxy.cfg:
  file.managed:
    - source: salt://haproxy/haproxy.cfg.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: True
    - dir_mode: 755
    - defaults:
      bind_ip: "127.0.0.1"

/etc/kubernetes/manifests/haproxy.manifest:
  file.managed:
    - source: salt://haproxy/haproxy.manifest
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: True
    - dir_mode: 755

# send a HUP to haproxy when the config changes
haproxy_restart:
  cmd.run:
    # we use a for loop here because this may run before haproxy starts, which is harmless, because
    # we only care about sending the HUP when the configuration changes after the initial deployment
    - name: |-
            for i in $(docker ps -a | grep haproxy-k8-api | awk '{print $1}')
            do 
              docker kill -HUP $i 
            done
    - watch:
      - file: /etc/haproxy/haproxy.cfg