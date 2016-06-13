log_new_minion:
  local.cmd.run:
    - name: log new minion
    - tgt: salt-master.domain.tld
    - arg:
      - 'logger -t salt-reactor "[{{ data['id'] }}][minion started] A new Minion has (re)born. "'

new_minion_cert:
  local.cmd.run:
    - name: new httpd frontend added to pool
    - tgt: salt-master.domain.tld
    - arg:
      - '/srv/salt/certs/certs.sh {{ data['id'] }}'
