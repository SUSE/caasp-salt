include:
  - crypto

{% set ip_addresses = [] -%}

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
{% set extra_names = ["DNS: " + grains['fqdn'],
                      "DNS: api",
                      "DNS: api." + pillar['internal_infra_domain']] %}
{% for extra_name in pillar['api']['server']['extra_names'] %}
  {% do extra_names.append("DNS: " + extra_name) %}
{% endfor %}

# add some standard extra names from the DNS domain
{% if salt['pillar.get']('dns:domain') %}
  {% do extra_names.append("DNS: kubernetes.default.svc." + pillar['dns']['domain']) %}
{% endif %}

/etc/pki/apiserver.key:
  x509.private_key_managed:
    - bits: 4096
    - require:
      - sls:  crypto
      - file: /etc/pki
  file.managed:
    - replace: false
    - user: root
    - group: root
    - mode: 644

/etc/pki/apiserver.crt:
  x509.certificate_managed:
    - ca_server: {{ salt['mine.get']('roles:ca', 'ca_cert', expr_form='grain').keys()[0] }}
    - signing_policy: minion
    - public_key: /etc/pki/apiserver.key
    - CN: {{ grains['fqdn'] }}
    - C: {{ pillar['certificate_information']['subject_properties']['C'] }}
    - Email: {{ pillar['certificate_information']['subject_properties']['Email'] }}
    - GN: {{ pillar['certificate_information']['subject_properties']['GN'] }}
    - L: {{ pillar['certificate_information']['subject_properties']['L'] }}
    - O: {{ pillar['certificate_information']['subject_properties']['O'] }}
    - OU: {{ pillar['certificate_information']['subject_properties']['OU'] }}
    - SN: {{ pillar['certificate_information']['subject_properties']['SN'] }}
    - ST: {{ pillar['certificate_information']['subject_properties']['ST'] }}
    - basicConstraints: "critical CA:false"
    - keyUsage: nonRepudiation, digitalSignature, keyEncipherment
    {% if ip_addresses|length > 0 %}
    - subjectAltName: "{{ ", ".join(ip_addresses) }}"
    {% endif %}
    - days_valid: {{ pillar['certificate_information']['days_valid']['certificate'] }}
    - days_remaining: {{ pillar['certificate_information']['days_remaining']['certificate'] }}
    - backup: True
    - require:
      - sls:  crypto
      - file: /etc/pki
  file.managed:
    - replace: false
    - user: root
    - group: root
    - mode: 644

mine.send:
  module.run:
    - func: apiserver
    - kwargs:
        mine_function: x509.get_pem_entries
        glob_path: /etc/pki/apiserver.*
    - onchanges:
      - x509: /etc/pki/apiserver.crt
      - x509: /etc/pki/apiserver.key
