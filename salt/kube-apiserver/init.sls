include:
  - repositories
  - ca-cert
  - cert
  - etcd
  - kubernetes-common
  - kubernetes-common.serviceaccount-key

{% from '_macros/certs.jinja' import certs with context %}
{{ certs("kube-apiserver",
         pillar['ssl']['kube_apiserver_crt'],
         pillar['ssl']['kube_apiserver_key'],
         cn = grains['caasp_fqdn'],
         o = pillar['certificate_information']['subject_properties']['O']) }}

kube-apiserver:
  pkg.installed:
    - pkgs:
      - kubernetes-master
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  file.managed:
    - name:       /etc/kubernetes/apiserver
    - source:     salt://kube-apiserver/apiserver.jinja
    - template:   jinja
  service.running:
    - enable:     True
    - require:
      - sls:             ca-cert
      - caasp_retriable: {{ pillar['ssl']['kube_apiserver_crt'] }}
      - x509:            {{ pillar['paths']['service_account_key'] }}
    - watch:
      - sls:             kubernetes-common
      - file:            kube-apiserver
      - sls:             ca-cert
      - caasp_retriable: {{ pillar['ssl']['kube_apiserver_crt'] }}
      - x509:            {{ pillar['paths']['service_account_key'] }}
  # wait until the API server is actually up and running
  http.wait_for_successful_query:
    {% set api_server = "api." + pillar['internal_infra_domain']  -%}
    {% set api_ssl_port = salt['pillar.get']('api:ssl_port', '6443') -%}
    - name:       {{ 'https://' + api_server + ':' + api_ssl_port }}/healthz
    - wait_for:   300
    - ca_bundle:  {{ pillar['ssl']['ca_file'] }}
    - status:     200
    - watch:
      - service:  kube-apiserver
