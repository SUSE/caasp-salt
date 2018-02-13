include:
  - repositories
  - ca-cert
  - cert
  - kubernetes-common
  - kubernetes-common.serviceaccount-key

{% from '_macros/certs.jinja' import certs with context %}
{{ certs("kube-apiserver",
         pillar['ssl']['kube_apiserver_crt'],
         pillar['ssl']['kube_apiserver_key'],
         cn = grains['nodename'],
         o = pillar['certificate_information']['subject_properties']['O']) }}

kube-apiserver:
  pkg.installed:
    - pkgs:
      - iptables
      - kubernetes-master
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  caasp_retriable.retry:
    - name: iptables-kube-apiserver
    - target: iptables.append
    - retry:
        attempts: 2
    - table:      filter
    - family:     ipv4
    - chain:      INPUT
    - jump:       ACCEPT
    - match:      state
    - connstate:  NEW
    - dports:
      - {{ pillar['api']['int_ssl_port'] }}
    - proto:      tcp
    - require:
      - sls:      kubernetes-common
  file.managed:
    - name:       /etc/kubernetes/apiserver
    - source:     salt://kube-apiserver/apiserver.jinja
    - template:   jinja
  service.running:
    - enable:     True
    - require:
      - caasp_retriable: iptables-kube-apiserver
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
    {% set api_ssl_port = pillar['api']['int_ssl_port'] -%}
    - name:       {{ 'https://' + api_server + ':' + api_ssl_port }}/healthz
    - wait_for:   300
    - ca_bundle:  {{ pillar['ssl']['ca_file'] }}
    - status:     200
    - watch:
      - service:  kube-apiserver

# Wait for the kube-apiserver to be answering on any location. Even if our local instance is already
# up, it could happen that HAProxy did not yet realize it's up, so let's wait until HAProxy agrees
# with us.
kube-apiserver-up:
  http.wait_for_successful_query:
    {% set api_server = "api." + pillar['internal_infra_domain']  -%}
    {% set api_ssl_port = pillar['api']['ssl_port'] -%}
    - name:       {{ 'https://' + api_server + ':' + api_ssl_port }}/healthz
    - wait_for:   300
    - ca_bundle:  {{ pillar['ssl']['ca_file'] }}
    - status:     200
    - watch:
      - service:  kube-apiserver
