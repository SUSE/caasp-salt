include:
  - ca-cert
  - cert

kubelet_stop:
  cmd.run:
    - name: systemctl stop kubelet

# NOTE: Remove me for 4.0

/etc/caasp/haproxy/haproxy.cfg:
  file.managed:
    - source: salt://migrations/2-3/haproxy/haproxy.cfg.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: True
    - dir_mode: 755
    - require:
      - kubelet_stop

{% from '_macros/certs.jinja' import certs, alt_master_names with context %}
{{ certs("kube-apiserver-proxy",
         pillar['ssl']['kube_apiserver_proxy_crt'],
         pillar['ssl']['kube_apiserver_proxy_key'],
         cn = grains['nodename'] + '-proxy',
         o = pillar['certificate_information']['subject_properties']['O'],
         extra_alt_names = alt_master_names()) }}

haproxy:
  file.managed:
    - name: /etc/kubernetes/manifests/haproxy.yaml
    - source: salt://migrations/2-3/haproxy/haproxy.yaml.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - makedirs: True
    - dir_mode: 755
    - require:
      - kubelet_stop
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

haproxy_kill:
  cmd.run:
    - name: |-
        haproxy_ids=$(docker ps | grep -E "k8s_(POD_)?haproxy.*_kube-system_" | awk '{print $1}')
        if [ -n "$haproxy_ids" ]; then
            docker kill $haproxy_ids
        fi
    - check_cmd:
      - /bin/true
    - require:
      - file: haproxy

kubelet_start:
  cmd.run:
    - name: systemctl start kubelet
    - require:
      - haproxy_kill

{%- set api_server = 'api.' + pillar['internal_infra_domain'] %}
wait-for-haproxy:
  caasp_retriable.retry:
    - target:     http.wait_for_successful_query
    - name:       {{ 'https://' + api_server + ':' + pillar['api']['ssl_port'] }}/healthz
    - wait_for:   300
    # retry just in case the API server returns a transient error
    - retry:
        attempts: 3
    - ca_bundle:  {{ pillar['ssl']['ca_file'] }}
    - status:     200
    - opts:
        http_request_timeout: 30
    - onchanges:
      - kubelet_start
