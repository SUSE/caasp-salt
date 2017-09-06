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

kube_apiserver_ready:
  # We need to wait for Kube API server to actually start, see k8s issue #47739
  # Salt's retry mechanism doesn't support specifying certs or keys
  # so I'm doing a horrible hack right now.
  cmd.run:
    - name: |
        {% set api_server = "api." + pillar['internal_infra_domain']  -%}
        {% set api_ssl_port = salt['pillar.get']('api:ssl_port', '6443') -%}
        {% set api_server_url = 'https://' + api_server + ':' + api_ssl_port -%}

        ELAPSED=0
        until curl --silent --fail -o /dev/null --cacert {{ pillar['ssl']['ca_file'] }} --cert {{ pillar['ssl']['crt_file'] }} --key {{ pillar['ssl']['key_file'] }} {{ api_server_url }}/healthz ; do
          [ $ELAPSED -gt 300 ] && exit 1
          sleep 1 && ELAPSED=$(( $ELAPSED + 1 ))
        done
        echo changed="no"
    - stateful: True

apply-namespace:
  cmd.run:
    - name: |
        kubectl apply -f /etc/kubernetes/addons/namespace.yaml || kubectl apply -f /etc/kubernetes/addons/namespace.yaml
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube_apiserver_ready
      - file:      /etc/kubernetes/addons/namespace.yaml

{% if salt['pillar.get']('addons:dns', 'false').lower() == 'true' %}
/etc/kubernetes/addons/kubedns.yaml:
  file.managed:
    - source:      salt://addons/addons/kubedns.yaml.jinja
    - template:    jinja

apply-dns:
  cmd.run:
    - name: |
        kubectl apply -f /etc/kubernetes/addons/kubedns.yaml || kubectl apply -f /etc/kubernetes/addons/kubedns.yaml
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube_apiserver_ready
      - file:      /etc/kubernetes/addons/kubedns.yaml

create-dns-clusterrolebinding:
  cmd.run:
    - name: |
        kubectl create clusterrolebinding system:kube-dns --clusterrole=cluster-admin --serviceaccount=kube-system:default
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - unless:
      - kubectl get clusterrolebindings | grep kube-dns | cat
    - require:
      - kube_apiserver_ready
{% endif %}

{% if salt['pillar.get']('addons:tiller', 'false').lower() == 'true' %}
/etc/kubernetes/addons/tiller.yaml:
  file.managed:
    - source:      salt://addons/addons/tiller.yaml.jinja
    - template:    jinja

apply-tiller:
  cmd.run:
    - name: |
        kubectl apply -f /etc/kubernetes/addons/tiller.yaml || kubectl apply -f /etc/kubernetes/addons/tiller.yaml
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube_apiserver_ready
      - file:      /etc/kubernetes/addons/tiller.yaml
{% endif %}