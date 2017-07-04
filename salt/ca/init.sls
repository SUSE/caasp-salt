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

/etc/pki/issued_certs:
  file.directory:
    - user: root
    - group: root
    - mode: 755

/etc/pki/ca.key:
  file.managed:
    - replace: false
    - user: root
    - group: root
    - mode: 400

/etc/pki/ca.crt:
  file.managed:
    - replace: false
    - user: root
    - group: root
    - mode: 644

mine.send:
  module.run:
    - func: ca.crt
    - kwargs:
        mine_function: x509.get_pem_entries
        glob_path: /etc/pki/ca.crt
