include:
  - crypto

salt-minion:
  service.running:
    - enable: True
    - listen:
      - file: /etc/salt/minion.d/signing_policies.conf

/etc/salt/minion.d/signing_policies.conf:
  file.managed:
    - source: salt://ca/signing_policies.conf.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 644

/etc/pki/issued_certs:
  file.directory:
    - user: root
    - group: root
    - mode: 755

/etc/pki/ca.key:
  x509.private_key_managed:
    - bits: 4096
    - backup: True
    - require:
      - sls:  crypto
      - file: /etc/pki
  file.managed:
    - user: root
    - group: root
    - mode: 600

/etc/pki/ca.crt:
  x509.certificate_managed:
    - signing_private_key: /etc/pki/ca.key
    - CN: {{ grains['domain'] }}
    - C: {{ pillar['certificate_information']['subject_properties']['C'] }}
    - Email: {{ pillar['certificate_information']['subject_properties']['Email'] }}
    - GN: {{ pillar['certificate_information']['subject_properties']['GN'] }}
    - L: {{ pillar['certificate_information']['subject_properties']['L'] }}
    - O: {{ pillar['certificate_information']['subject_properties']['O'] }}
    - OU: {{ pillar['certificate_information']['subject_properties']['OU'] }}
    - SN: {{ pillar['certificate_information']['subject_properties']['SN'] }}
    - ST: {{ pillar['certificate_information']['subject_properties']['ST'] }}
    - basicConstraints: "critical CA:true"
    - keyUsage: "critical cRLSign, keyCertSign"
    - subjectKeyIdentifier: hash
    - authorityKeyIdentifier: keyid,issuer:always
    - days_valid: {{ pillar['certificate_information']['days_valid']['ca_certificate'] }}
    - days_remaining: {{ pillar['certificate_information']['days_remaining']['ca_certificate'] }}
    - backup: True
    - require:
      - sls:  crypto
      - x509: /etc/pki/ca.key
  file.managed:
    - user: root
    - group: root
    - mode: 644

mine.send:
  module.run:
    - func: x509.get_pem_entries
    - kwargs:
        glob_path: /etc/pki/ca.crt
    - onchanges:
      - x509: /etc/pki/ca.crt
