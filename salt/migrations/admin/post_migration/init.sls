# This state only removes the grains and reenables the transaction-update.

# It is split into another file, because the admin node also hosts the
# salt-master - so it can not be rebooted and waited on as the salt-master will
# also be rebooted.

reenable-transactional-update-timer:
  service.running:
    - name: transactional-update.timer

{% for grain in 'tx_update_migration_available', 'tx_update_migration_notes', 'tx_update_migration_mirror_synced', 'migration_in_progress' %}
unset-{{ grain }}-grain:
  grains.absent:
    - name: {{ grain }}
    - destructive: true
{% endfor %}

reset-minion-startup:
  file.replace:
    - name: /etc/salt/minion
    - repl: |
        #startup_states: ''
        #
        # List of states to run when the minion starts up if startup_states is 'sls':
        #sls_list:
        #  - edit.vim
        #  - hyper
    - pattern: |
        startup_states: sls
        sls_list:
          - migrations.admin.post_migration
