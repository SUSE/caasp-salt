{#- Get a list of nodes seem to be down or unresponsive #}
{#- This sends a "are you still there?" message to all #}
{#- the nodes and wait for a response, so it takes some time. #}

{%- set parallelism = salt['pillar.get']('parallelism', 3) %}
{%- set nodes_down = salt.saltutil.runner('manage.down') %}
{%- if nodes_down|length >= 1 %}
# {{ nodes_down|join(',') }} seem to be down: skipping
  {%- set is_responsive_node_tgt = 'not L@' + nodes_down|join(',') %}
{%- else %}
# all nodes seem to be up
  {#- we cannot leave this empty (it would produce many " and <empty>" targets) #}
  {%- set is_responsive_node_tgt = '*' %}
{%- endif %}

{%- set is_migratable = is_responsive_node_tgt + ' and G@tx_update_migration_available:true' %}
{%- set is_admin = is_migratable + ' and G@roles:admin' %}

set-migration-grain:
  salt.function:
    - tgt: '{{ is_migratable }}'
    - tgt_type: compound
    - name: grains.setval
    - arg:
        - migration_in_progress
        - true

# We have to disable the transactional-update.timer to prevent interference with
# our update. The timer could create a newer snapshot otherwise and break the
# update after a reboot by booting into the assumed newer snapshot that was
# created after our migration.
disable-transactional-update-timer:
  salt.function:
    - tgt: '{{ is_migratable }}'
    - tgt_type: compound
    - batch: {{ parallelism }}
    - name: service.disable
    - arg:
        - transactional-update.timer

run-transactional-migration:
  salt.function:
    - tgt: '{{ is_migratable }}'
    - tgt_type: compound
    - batch: {{ parallelism }}
    - name: cmd.run
    - arg:
        - transactional-update migration -n salt 2>&1 | tee /var/log/migration_$(date -I).txt
    - kwarg:
        python_shell: true
    - require:
        - disable-transactional-update-timer

update-data:
  salt.function:
    - tgt: '{{ is_migratable }}'
    - tgt_type: compound
    - names:
      - saltutil.refresh_pillar
      - saltutil.refresh_grains
    - require:
        - run-transactional-migration

set-startup-state:
  salt.state:
    - tgt: '{{ is_admin }}'
    - tgt_type: compound
    - sls:
        - migrations.admin.startup
    - require:
        - update-data

reboot-admin:
  salt.function:
    - tgt: '{{ is_admin }}'
    - tgt_type: compound
    - name: system.reboot
    - require:
        - set-startup-state
