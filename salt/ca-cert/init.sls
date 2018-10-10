include:
  - crypto

{%- set ca_crt = salt['mine.get']('roles:ca', 'ca.crt', expr_form='grain').values()|first %}

{{ pillar['ssl']['ca_dir'] }}:
  file.directory:
    - makedirs: True
    - user: root
    - group: root
    - mode: 755

{{ pillar['ssl']['ca_file'] }}:
  x509.pem_managed:
    - text: {{ ca_crt['/etc/pki/ca.crt']|replace('\n', '') }}
    - user: root
    - group: root
    - mode: 644
    - require:
      - file: {{ pillar['ssl']['ca_dir'] }}
