include:
  - ca-cert
  - cert

{% set ip_addresses = [] -%}
{% set extra_names = ["DNS: " + grains['caasp_fqdn'], "DNS: " + pillar['dashboard_external_fqdn']] -%}

{% if salt['caasp_filters.is_ip'](pillar['dashboard']) %}
{% do ip_addresses.append("IP: " + pillar['dashboard']) %}
{% else %}
{% do extra_names.append("DNS: " + pillar['dashboard']) %}
{% endif %}

{{ pillar['ssl']['velum_key'] }}:
  x509.private_key_managed:
    - bits: 4096
    - user: root
    - group: root
    - mode: 444
    - require:
      - sls:  crypto
      - file: /etc/pki

{{ pillar['ssl']['velum_crt'] }}:
  x509.certificate_managed:
    - ca_server: {{ salt['mine.get']('roles:ca', 'ca.crt', expr_form='grain').keys()[0] }}
    - signing_policy: minion
    - public_key: {{ pillar['ssl']['velum_key'] }}
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
      - {{ pillar['ssl']['velum_key'] }}

# TODO: We should not restart the Velum container, but this is required for the new certificates to
#       be loaded. Soon, we should stop serving content directly with Puma and it should be done
#       by web servers instead of application servers (apache, nginx...).
# TODO: This has been disabled, as the reload means a new cert warning is presented - breaking Velum's
#       background polling. Velum's polling needs to be adapted to handle this, and once done, this can
#       enabled again.
# velum_restart:
#   cmd.run:
#     - name: |-
#         velum_id=$(docker ps | grep "velum-dashboard" | awk '{print $1}')
#         if [ -n "$velum_id" ]; then
#             docker restart $velum_id
#         fi
#     - onchanges:
#       - x509: {{ pillar['ssl']['velum_key'] }}
#       - x509: {{ pillar['ssl']['velum_crt'] }}
