include:
  - crypto

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