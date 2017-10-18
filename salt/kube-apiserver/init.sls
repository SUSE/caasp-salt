include:
  - repositories
  - ca-cert
  - cert
  - etcd
  - kubernetes-common
  - kubernetes-common.serviceaccount-key

{% from '_macros/certs.jinja' import extra_master_names, certs with context %}
{{ certs("kube-apiserver",
         pillar['ssl']['kube_apiserver_crt'],
         pillar['ssl']['kube_apiserver_key'],
         cn = grains['caasp_fqdn'],
         o = pillar['certificate_information']['subject_properties']['O'],
         extra = extra_master_names()) }}

kube-apiserver:
  pkg.installed:
    - pkgs:
      - iptables
      - kubernetes-master
    - require:
      - file: /etc/zypp/repos.d/containers.repo
  iptables.append:
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
      - iptables: kube-apiserver
      - sls:      ca-cert
      - x509:     {{ pillar['ssl']['kube_apiserver_crt'] }}
      - x509:     {{ pillar['paths']['service_account_key'] }}
    - watch:
      - sls:      kubernetes-common
      - file:     kube-apiserver
      - sls:      ca-cert
      - x509:     {{ pillar['ssl']['kube_apiserver_crt'] }}
      - x509:     {{ pillar['paths']['service_account_key'] }}
  # wait until the API server is actually up and running
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
