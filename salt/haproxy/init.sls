include:
  - ca-cert
  - cert
  - etc-hosts
{% if salt.caasp_nodes.is_admin_node() %}
  - velum
{% else %}
# This state is executed also on the admin node. On the admin
# node we cannot require the kubelet state otherwise the node will
# join the kubernetes cluster and some system workloads might be
# scheduled there. All these services would then fail due to the network
# not being configured properly, and that would lead to slow and always
# failing orchestrations.
  - kubelet
  - {{ salt['pillar.get']('cri:chosen', 'docker') }}
{% endif %}

{% from '_macros/certs.jinja' import certs, alt_master_names with context %}

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

{% if salt.caasp_pillar.get('external_cert:kube_api:cert', False)
  and salt.caasp_pillar.get('external_cert:kube_api:key',  False)
%}

{% from '_macros/certs.jinja' import external_pillar_certs with context %}

{{ external_pillar_certs(
      pillar['ssl']['kube_apiserver_proxy_crt'],
      'external_cert:kube_api:cert',
      pillar['ssl']['kube_apiserver_proxy_key'],
      'external_cert:kube_api:key',
      bundle=pillar['ssl']['kube_apiserver_proxy_bundle']
) }}

{% else %}

{{ certs("kube-apiserver-proxy",
         pillar['ssl']['kube_apiserver_proxy_crt'],
         pillar['ssl']['kube_apiserver_proxy_key'],
         cn = grains['nodename'] + '-proxy',
         o = pillar['certificate_information']['subject_properties']['O'],
         extra_alt_names = alt_master_names(),
         bundle=pillar['ssl']['kube_apiserver_proxy_bundle']) }}

{% endif %}

# HAproxy client auth cert
{{ certs("kube-apiserver-haproxy",
         pillar['ssl']['kube_apiserver_haproxy_crt'],
         pillar['ssl']['kube_apiserver_haproxy_key'],
         cn = grains['nodename'] + '-haproxy',
         o = pillar['certificate_information']['subject_properties']['O'],
         bundle=pillar['ssl']['kube_apiserver_haproxy_bundle']) }}

haproxy:
  caasp_file.managed:
    - name: /etc/kubernetes/manifests/haproxy.yaml
    - source: salt://haproxy/haproxy.yaml.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: True
    - work_dir: /tmp
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
      - caasp_file: haproxy
      - file: /etc/caasp/haproxy/haproxy.cfg
{% if salt.caasp_nodes.is_admin_node() %}
      - file: {{ pillar['ssl']['velum_bundle'] }}
{% else %}
      - file: {{ pillar['ssl']['kube_apiserver_proxy_bundle'] }}
      - file: {{ pillar['ssl']['kube_apiserver_haproxy_bundle'] }}
    - require:
      - service: kubelet
{% endif %}


{% if 'admin' in salt['grains.get']('roles', []) %}
# The admin node is serving the internal API with the pillars. Wait for it to come back
# before going on with the orchestration/highstates.
wait-for-haproxy:
  caasp_retriable.retry:
    - target:     http.wait_for_successful_query
    - name:       https://localhost:444/_health
    - wait_for:   300
    - status:     200
    - verify_ssl: False
    - opts:
        http_request_timeout: 30
    - onchanges:
      - haproxy-restart
{% else %}
# If we are not on the admin node, still wait for haproxy to be back. We don't know what
# will be executed afterwards; it could require access to the apiserver, so the safest
# thing to do is to wait for haproxy to be back and serving requests.
{%- set api_server = 'api.' + pillar['internal_infra_domain'] %}
wait-for-haproxy:
  caasp_retriable.retry:
    - target:     http.wait_for_successful_query
    - name:       {{ 'https://' + api_server + ':' + pillar['api']['ssl_port'] }}/healthz
    - wait_for:   300
    # retry just in case the API server returns a transient error
    - retry:
        attempts: 3
    - ca_bundle:  {{ pillar['ssl']['sys_ca_bundle'] }}
    - status:     200
    - opts:
        http_request_timeout: 30
    - onchanges:
      - haproxy-restart
{% endif %}
