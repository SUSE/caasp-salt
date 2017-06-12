include:
  - crypto

# If we are in a docker container, `service.running` fails with error:
#
# "No service execution module loaded: check support for service management on Leap-42"
#
# Anyway, no need to check for the service on the docker container, since it is the PID 1,
# so if it's not running, the container is gone.
#
# Additionally, virtual grains report `kvm` virtualization, so we just need to check if
# /.dockerenv file exists to detect if we are running inside a docker container.
#
# Bug report: https://github.com/saltstack/salt/issues/22467
#
# Outside a container salt-minion service will listen for signing_policies file changes and
# restart the service. Inside a container we mount this file, so when the salt minion starts
# signing policies are already on filesystem and there is no need to restart the minion
# service.
{% if not salt['file.file_exists']('/.dockerenv') %}
salt-minion:
  service.running:
    - enable: True
    - listen:
      - file: /etc/salt/minion.d/signing_policies.conf

/etc/salt/minion.d/signing_policies.conf:
  file.managed:
    - source: salt://ca/signing_policies.conf
    - user: root
    - group: root
    - mode: 644
{% endif %}

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
    - replace: false
    - user: root
    - group: root
    - mode: 600

/etc/pki/ca.crt:
  x509.certificate_managed:
    - signing_private_key: /etc/pki/ca.key
{% if salt['grains.get']('domain', '')|length > 0 %}
    - CN: {{ grains['domain'] }}
{% elif salt['pillar.get']('dns:domain', '')|length > 0 %}
    - CN: {{ pillar['dns']['domain'] }}
{% else %}
    - CN: kubernetes
{% endif %}
    - C: DE
    - Email:
    - GN:
    - L: Nuremberg
    - O: SUSE
    - OU: Containers Team
    - SN:
    - ST: Bavaria
    - basicConstraints: "critical CA:true"
    - keyUsage: "critical cRLSign, keyCertSign"
    - subjectKeyIdentifier: hash
    - authorityKeyIdentifier: keyid,issuer:always
    - days_valid: 3650
    - days_remaining: 90
    - backup: True
    - require:
      - sls:  crypto
      - x509: /etc/pki/ca.key
  file.managed:
    - replace: false
    - user: root
    - group: root
    - mode: 644

mine.send:
  module.wait:
    - func: x509.get_pem_entries
    - kwargs:
        glob_path: /etc/pki/ca.crt
    - watch:
      - x509: /etc/pki/ca.crt
