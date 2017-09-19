include:
  - crypto

generate-serviceaccount-key:
  x509.private_key_managed:
    - name: /etc/pki/sa.key
    - bits: 4096
    - user: root
    - group: root
    - mode: 444
    - require:
      - sls:  crypto
