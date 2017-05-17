/etc/pki/etcd.key:
  x509.pem_managed:
    - text: {{ salt['mine.get']('roles:ca', 'etcd', expr_form='grain').values()[0]['/etc/pki/etcd.key']|replace('\n', '') }}
  file.managed:
    - replace: false
    - user: root
    - group: root
    - mode: 644

/etc/pki/etcd.crt:
  x509.pem_managed:
    - text: {{ salt['mine.get']('roles:ca', 'etcd', expr_form='grain').values()[0]['/etc/pki/etcd.crt']|replace('\n', '') }}
  file.managed:
    - replace: false
    - user: root
    - group: root
    - mode: 644