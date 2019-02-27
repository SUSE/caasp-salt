{#- Make sure we start with an updated mine #}
{%- set _ = salt.caasp_orch.sync_all() %}

{#- Get a list of nodes seem to be down or unresponsive #}
{#- This sends a "are you still there?" message to all #}
{#- the nodes and wait for a response, so it takes some time. #}

{%- set default_batch = salt['pillar.get']('default_batch', 5) %}
{#- tx_update_migration_available needs to be last, as it is still used as a selector til reboot #}
{%- set migration_grains = ['tx_update_migration_notes', 'tx_update_migration_newversion', 'migration_in_progress', 'tx_update_migration_available'] %}

{%- set nodes_down = salt.saltutil.runner('manage.down') %}
{%- if nodes_down|length >= 1 %}
# {{ nodes_down|join(',') }} seem to be down: skipping
  {%- do salt.caasp_log.debug('CaaS: nodes "%s" seem to be down: ignored', nodes_down|join(',')) %}
  {%- set is_responsive_node_tgt = 'not L@' + nodes_down|join(',') %}
{%- else %}
# all nodes seem to be up
  {%- do salt.caasp_log.debug('CaaS: all nodes seem to be up') %}
  {#- we cannot leave this empty (it would produce many " and <empty>" targets) #}
  {%- set is_responsive_node_tgt = '*' %}
{%- endif %}

{%- set is_migrateable = is_responsive_node_tgt + ' and G@tx_update_migration_available:true' %}

{%- set is_migrateable_admin = 'G@tx_update_migration_available:true and G@roles:admin' %}

set-progress-grain:
  salt.function:
    - tgt: '{{ is_migrateable_admin }}'
    - tgt_type: grains
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
    - tgt: '{{ is_migrateable }}'
    - tgt_type: compound
    - batch: {{ default_batch }}
    - name: service.disable
    - arg:
        - transactional-update.timer

run-transactional-migration:
  salt.state:
    - tgt: '{{ is_migrateable }}'
    - tgt_type: compound
    - batch: {{ default_batch }}
    - sls:
      - transactional-update.migration
    - require:
        - disable-transactional-update-timer

update-data:
  salt.function:
    - tgt: '{{ is_migrateable }}'
    - tgt_type: compound
    - names:
      - saltutil.refresh_pillar
      - saltutil.refresh_grains
    - require:
        - run-transactional-migration

{%- for grain in migration_grains %}
unset-admin-grain-{{ grain }}:
  salt.function:
    - name: grains.delval
    - tgt: '{{ is_migrateable_admin }}'
    - tgt_type: compound
    - arg:
        - {{ grain }}
    - kwarg:
        destructive: true
    - require:
        - update-data
{%- endfor %}

reboot-admin:
  salt.function:
    - tgt: 'G@roles:admin'
    - tgt_type: compound
    - name: cmd.run
    - arg:
        - sleep 15; systemctl reboot
    - kwarg:
        bg: true
    - require:
{%- for grain in migration_grains %}
        - unset-admin-grain-{{ grain }}
{%- endfor %}
