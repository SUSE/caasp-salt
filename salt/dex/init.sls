include:
  - crypto
  - repositories
  - kubectl-config
  - kube-apiserver

{% set ip_addresses = [] -%}
{% set extra_names = ["DNS: " + grains['caasp_fqdn'] ] -%}
{% if "kube-master" in salt['grains.get']('roles', []) %}
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
  {% set extra_names = extra_names + ["DNS: dex",
                                      "DNS: dex.kube-system",
                                      "DNS: dex.kube-system.svc",
                                      "DNS: dex.kube-system.svc." + pillar['internal_infra_domain'],
                                      "DNS: api." + pillar['internal_infra_domain']] %}
  {% for extra_name in pillar['api']['server']['extra_names'] %}
    {% do extra_names.append("DNS: " + extra_name) %}
  {% endfor %}

  # add the fqdn provided by the user
  # this will be the name used by the kubeconfig generated file
  {% if salt['pillar.get']('api:server:external_fqdn') %}
    {% do extra_names.append("DNS: " + pillar['api']['server']['external_fqdn']) %}
  {% endif %}
{% endif %}

/etc/pki/dex.key:
  x509.private_key_managed:
    - bits: 4096
    - user: root
    - group: root
    - mode: 444
    - require:
      - sls:  crypto
      - file: /etc/pki

/etc/pki/dex.crt:
  x509.certificate_managed:
    - ca_server: {{ salt['mine.get']('roles:ca', 'ca.crt', expr_form='grain').keys()[0] }}
    - signing_policy: minion
    - public_key: /etc/pki/dex.key
    - CN: Dex
    {% if (ip_addresses|length > 0) or (extra_names|length > 0) %}
    - subjectAltName: "{{ ", ".join(extra_names + ip_addresses) }}"
    {% endif %}
    - basicConstraints: "critical CA:false"
    - keyUsage: nonRepudiation, digitalSignature, keyEncipherment
    - days_valid: {{ pillar['certificate_information']['days_valid']['certificate'] }}
    - days_remaining: {{ pillar['certificate_information']['days_remaining']['certificate'] }}
    - backup: True
    - user: root
    - group: root
    - mode: 644
    - require:
      - sls:  crypto
      - x509: /etc/pki/dex.key

/root/dex.yaml:
  file.managed:
    - source: salt://dex/dex.yaml
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - require:
      - x509: /etc/pki/dex.crt

/root/roles.yaml:
  file.managed:
    - source: salt://dex/roles.yaml
    - template: jinja
    - user: root
    - group: root
    - mode: 644
    - require:
      - file: /root/dex.yaml

dex_secrets:
  cmd.run:
    - name: |
        until kubectl get secret dex-tls --namespace=kube-system ; do
            kubectl create secret generic dex-tls --namespace=kube-system --from-file=/etc/pki/dex.crt --from-file=/etc/pki/dex.key
            sleep 5
        done
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube-apiserver
      - x509: /etc/pki/dex.crt
      - {{ pillar['paths']['kubeconfig'] }}

dex_instance:
  caasp_cmd.run:
    - name: |
        kubectl apply -f /root/dex.yaml
    - retry:
        attempts: 10
        interval: 1
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube-apiserver
      - file: /root/dex.yaml
      - {{ pillar['paths']['kubeconfig'] }}

kubernetes_roles:
  caasp_cmd.run:
    - name: |
        kubectl apply -f /root/roles.yaml
    - retry:
        attempts: 10
        interval: 1
    - env:
      - KUBECONFIG: {{ pillar['paths']['kubeconfig'] }}
    - require:
      - kube-apiserver
      - file: /root/roles.yaml
      - {{ pillar['paths']['kubeconfig'] }}
      - dex_instance
