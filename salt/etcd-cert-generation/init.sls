include:
  - crypto

/etc/pki/etcd.key:
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

/etc/pki/etcd.crt:
  x509.certificate_managed:
    - ca_server: {{ salt['mine.get']('roles:ca', 'ca_cert', expr_form='grain').keys()[0] }}
    - signing_policy: minion
    - public_key: /etc/pki/etcd.key
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

mine.send:
  module.run:
    - func: etcd
    - kwargs:
        mine_function: x509.get_pem_entries
        glob_path: /etc/pki/etcd.*
    - onchanges:
      - x509: /etc/pki/etcd.crt
      - x509: /etc/pki/etcd.key