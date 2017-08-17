include:
  - kube-apiserver
  - kubernetes-common

/etc/kubernetes/addons:
  file.directory:
    - user:     root
    - group:    root
    - dir_mode: 755
    - makedirs: True

/etc/kubernetes/addons/namespace.yaml:
  file.managed:
    - source:      salt://addons/addons/namespace.yaml.jinja
    - template:    jinja

{% if salt['pillar.get']('addons:dns', 'false').lower() == 'true' %}
/etc/kubernetes/addons/kubedns-sa.yaml:
  file.managed:
    - source:     salt://addons/addons/kubedns-sa.yaml.jinja
    - template:   jinja

/etc/kubernetes/addons/kubedns-cm.yaml:
  file.managed:
    - source:      salt://addons/addons/kubedns-cm.yaml.jinja
    - template:    jinja

/etc/kubernetes/addons/kubedns.yaml:
  file.managed:
    - source:      salt://addons/addons/kubedns.yaml.jinja
    - template:    jinja

/etc/kubernetes/addons/kubedns-svc.yaml:
  file.managed:
    - source:      salt://addons/addons/kubedns-svc.yaml.jinja
    - template:    jinja

kube_apiserver_ready:
  # We need to wait for Kube API server to actually start, see k8s issue #47739
  # TODO: Salt doesn't seem to have a retry mechanism in the version were using,
  # so I'm doing a horrible hack right now.
  cmd.run:
    - name: |
        ELAPSED=0
        until curl --insecure --silent --fail -o /dev/null http://127.0.0.1:8080/healthz ; do
            [ $ELAPSED -gt 300 ] && exit 1
            sleep 1 && ELAPSED=$(( $ELAPSED + 1 ))
        done
        echo changed="no"
    - stateful: True

deploy_addons.sh:
  cmd.script:
    - source:      salt://addons/deploy_addons.sh
    - require:
      - service:   kube-apiserver
      - file:      /etc/kubernetes/addons/namespace.yaml
      - file:      /etc/kubernetes/addons/kubedns-sa.yaml
      - file:      /etc/kubernetes/addons/kubedns-cm.yaml
      - file:      /etc/kubernetes/addons/kubedns-svc.yaml
      - file:      /etc/kubernetes/addons/kubedns.yaml
      - kube_apiserver_ready
{% endif %}

