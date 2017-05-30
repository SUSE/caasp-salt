include:
  - crypto

{% set ip_addresses = [] -%}
{% set extra_names = ["DNS: " + grains['fqdn']] -%}

{{ pillar['paths']['ca_dir'] }}:
  file.directory:
    - user: root
    - group: root
    - mode: 755

{{ pillar['paths']['ca_dir'] }}/{{ pillar['paths']['ca_filename'] }}:
  x509.pem_managed:
    - text: {{ salt['mine.get']('roles:ca', 'x509.get_pem_entries', expr_form='grain').values()[0]['/etc/pki/ca.crt']|replace('\n', '') }}
    - require:
      - file: {{ pillar['paths']['ca_dir'] }}
  file.managed:
    - replace: false
    - user: root
    - group: root
    - mode: 644

/etc/pki/minion.key:
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

/etc/pki/minion.crt:
  x509.certificate_managed:
    - ca_server: {{ salt['mine.get']('roles:ca', 'x509.get_pem_entries', expr_form='grain').keys()[0] }}
    - signing_policy: minion
    - public_key: /etc/pki/minion.key
    - CN: {{ grains['fqdn'] }}
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
    - require:
      - sls:  crypto
      - file: /etc/pki
  file.managed:
    - replace: false
    - user: root
    - group: root
    - mode: 644
