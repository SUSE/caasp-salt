ca_setup:
  salt.state:
    - tgt: 'roles:ca'
    - tgt_type: grain
    - highstate: True

infra_cert_setup:
  salt.state:
    - tgt: 'roles:admin'
    - tgt_type: grain
    - highstate: True
    - require:
      - salt: ca_setup

remove_cert_init_key:
  salt.wheel:
    - name: key.delete
    - match: cert-init
    - require:
      - salt: infra_cert_setup
