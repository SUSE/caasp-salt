/etc/pki/apiserver.key:
  x509.pem_managed:
    - text: {{ salt['mine.get']('roles:ca', 'apiserver', expr_form='grain').values()[0]['/etc/pki/apiserver.key']|replace('\n', '') }}
  file.managed:
    - replace: false
    - user: root
    - group: root
    - mode: 644

/etc/pki/apiserver.crt:
  x509.pem_managed:
    - text: {{ salt['mine.get']('roles:ca', 'apiserver', expr_form='grain').values()[0]['/etc/pki/apiserver.crt']|replace('\n', '') }}
  file.managed:
    - replace: false
    - user: root
    - group: root
    - mode: 644