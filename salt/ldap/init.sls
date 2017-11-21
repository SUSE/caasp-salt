include:
  - ca-cert
  - cert

{% set ip_addresses = [] -%}
{% set extra_names = ["DNS: " + grains['caasp_fqdn'], "DNS: " + pillar['dashboard_external_fqdn']] -%}

{% set dashboard = salt['pillar.get']('dashboard', '') %}
{% if salt['caasp_filters.is_ip'](dashboard) %}
  {% do ip_addresses.append("IP: " + dashboard) %}
{% else %}
  {% do extra_names.append("DNS: " + dashboard) %}
{% endif %}

{{ pillar['ssl']['ldap_key'] }}:
  x509.private_key_managed:
    - bits: 4096
    - user: root
    - group: root
    - mode: 444
    - require:
      - sls:  crypto
      - file: /etc/pki

{{ pillar['ssl']['ldap_crt'] }}:
  x509.certificate_managed:
    - ca_server: {{ salt['mine.get']('roles:ca', 'ca.crt', expr_form='grain').keys()[0] }}
    - signing_policy: minion
    - public_key: {{ pillar['ssl']['ldap_key'] }}
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
      - {{ pillar['ssl']['ldap_key'] }}

openldap_restart:
  cmd.run:
    - name: |-
        openldap_id=$(docker ps | grep "openldap" | awk '{print $1}')
        if [ -n "$openldap_id" ]; then
            docker restart $openldap_id
        fi
    - onchanges:
      - x509: {{ pillar['ssl']['ldap_key'] }}
      - x509: {{ pillar['ssl']['ldap_crt'] }}