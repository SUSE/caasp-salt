include:
  - crypto

{{ pillar['ssl']['ca_dir'] }}:
  file.directory:
    - user: root
    - group: root
    - mode: 755

{{ pillar['ssl']['ca_file'] }}:
  x509.pem_managed:
    - text: {{ salt['mine.get']('roles:ca', 'ca.crt', expr_form='grain').values()[0]['/etc/pki/ca.crt']|replace('\n', '') }}
    - require:
      - file: {{ pillar['ssl']['ca_dir'] }}
  file.managed:
    - replace: false
    - user: root
    - group: root
    - mode: 644

{{ pillar['ssl']['ca_public_file'] }}:
  x509.pem_managed:
    - text: {{ salt['mine.get']('roles:ca', 'public-ca.crt', expr_form='grain').values()[0]['/etc/pki/public-ca.crt']|replace('\n', '') }}
    - require:
      - file: {{ pillar['ssl']['ca_file'] }}
  file.managed:
    - replace: false
    - user: root
    - group: root
    - mode: 644
