include:
  - crypto

{% set subject_alt_names = [] -%}

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
    {% if subject_alt_names|length > 0 %}
    - subjectAltName: "{{ ", ".join(subject_alt_names) }}"
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
