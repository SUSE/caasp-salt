/etc/pki/sa.key:
  x509.pem_managed:
    - text: {{ salt['mine.get']('roles:ca', 'sa.key', expr_form='grain').values()[0]['/etc/pki/sa.key']|replace('\n', '') }}
    - user: root
    - group: root
    - mode: 640
