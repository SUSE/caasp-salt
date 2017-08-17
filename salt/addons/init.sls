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

deploy_addons.sh:
  # We need to wait for Kube API server to actually start, see k8s issue #47739
  http.wait_for_successful_query:
    - name:        'http://127.0.0.1:8080/healthz'
    - status:      200
  cmd.script:
    - source:      salt://addons/deploy_addons.sh
    - require:
      - service:   kube-apiserver
      - file:      /etc/kubernetes/addons/namespace.yaml
      - file:      /etc/kubernetes/addons/kubedns-sa.yaml
      - file:      /etc/kubernetes/addons/kubedns-cm.yaml
      - file:      /etc/kubernetes/addons/kubedns-svc.yaml
      - file:      /etc/kubernetes/addons/kubedns.yaml
{% endif %}

