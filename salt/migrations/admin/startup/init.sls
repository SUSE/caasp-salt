/etc/salt/minion:
  file.replace:
    - repl: |
        startup_states: sls
        sls_list:
          - migrations.admin.post_migration
    - pattern: |
        \#startup_states: ''
        \#
        \# List of states to run when the minion starts up if startup_states is 'sls':
        \#sls_list:
        \#  - edit.vim
        \#  - hyper
