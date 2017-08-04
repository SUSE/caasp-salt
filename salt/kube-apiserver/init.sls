include:
  - repositories
  - ca-cert
  - cert
  - etcd-proxy
  - kubernetes-common
  - kubernetes-minion

{% set api_ssl_port = salt['pillar.get']('api:ssl_port', '6443') %}

{% set ip_addresses = [] -%}
{% set extra_names = ["DNS: " + grains['caasp_fqdn'] ] -%}

{% do ip_addresses.append("IP: " + pillar['api']['cluster_ip']) %}
{% for _, interface_addresses in grains['ip4_interfaces'].items() %}
  {% for interface_address in interface_addresses %}
    {% do ip_addresses.append("IP: " + interface_address) %}
  {% endfor %}
{% endfor %}
{% for extra_ip in pillar['api']['server']['extra_ips'] %}
  {% do ip_addresses.append("IP: " + extra_ip) %}
{% endfor %}

# add some extra names the API server could have
{% set extra_names = extra_names + ["DNS: kubernetes",
                                    "DNS: kubernetes.default",
                                    "DNS: kubernetes.default.svc",
                                    "DNS: api",
                                    "DNS: api." + pillar['internal_infra_domain']] %}
{% for extra_name in pillar['api']['server']['extra_names'] %}
  {% do extra_names.append("DNS: " + extra_name) %}
{% endfor %}

# add the fqdn provided by the user
# this will be the name used by the kubeconfig generated file
{% if salt['pillar.get']('api:server:external_fqdn') %}
  {% do extra_names.append("DNS: " + pillar['api']['server']['external_fqdn']) %}
{% endif %}

# add some standard extra names from the DNS domain
{% if salt['pillar.get']('dns:domain') %}
  {% do extra_names.append("DNS: kubernetes.default.svc." + pillar['dns']['domain']) %}
{% endif %}

{{ pillar['ssl']['kube_apiserver_key'] }}:
  x509.private_key_managed:    
    - bits: 4096
    - user: root
    - group: root
    - mode: 444
    - require:
      - sls:  crypto
      - file: /etc/pki

{{ pillar['ssl']['kube_apiserver_crt'] }}:
  x509.certificate_managed:
    - ca_server: {{ salt['mine.get']('roles:ca', 'ca.crt', expr_form='grain').keys()[0] }}
    - signing_policy: minion
    - public_key: {{ pillar['ssl']['key_dir'] }}/kube-apiserver.key
    - CN: {{ grains['caasp_fqdn'] }}
    - C: {{ pillar['certificate_information']['subject_properties']['C']|yaml_dquote }}
    - Email: {{ pillar['certificate_information']['subject_properties']['Email']|yaml_dquote }}
    - GN: {{ pillar['certificate_information']['subject_properties']['GN']|yaml_dquote }}
    - L: {{ pillar['certificate_information']['subject_properties']['L']|yaml_dquote }}
    - O: {{ pillar['certificate_information']['subject_properties']['O']|yaml_dquote }}
    - OU: {{ pillar['certificate_information']['subject_properties']['OU']|yaml_dquote }}
    - SN: {{ pillar['certificate_information']['subject_properties']['SN']|yaml_dquote }}
    - ST: {{ pillar['certificate_information']['subject_properties']['ST']|yaml_dquote }}
    - basicConstraints: "critical CA:false"
    - keyUsage: nonRepudiation, digitalSignature, keyEncipherment
    {% if (ip_addresses|length > 0) or (extra_names|length > 0) %}
    - subjectAltName: "{{ ", ".join(extra_names + ip_addresses) }}"
    {% endif %}
    - days_valid: {{ pillar['certificate_information']['days_valid']['certificate'] }}
    - days_remaining: {{ pillar['certificate_information']['days_remaining']['certificate'] }}
    - backup: True
    - user: root
    - group: root
    - mode: 644
    - require:
      - sls:  crypto
      - {{ pillar['ssl']['kube_apiserver_key'] }}

kube-apiserver:
  pkg.installed:
    - pkgs:
      - iptables
      - etcdctl
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
        - {{ api_ssl_port }}
    - proto:      tcp
    - require:
      - pkg:      kubernetes-master
      - sls:      kubernetes-common
  file.managed:
    - name:       /etc/kubernetes/apiserver
    - source:     salt://kubernetes-master/apiserver.jinja
    - template:   jinja
    - require:
      - pkg:      kubernetes-master
  service.running:
    - enable:     True
    - require:
      - pkg:      kubernetes-master
      - iptables: kube-apiserver
      - sls:      ca-cert
      - {{ pillar['ssl']['kube_apiserver_crt'] }}
    - watch:
      - sls:      kubernetes-common
      - file:     kube-apiserver
      - sls:      ca-cert
      - {{ pillar['ssl']['kube_apiserver_crt'] }}
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
    - require:
      - service: kube-apiserver