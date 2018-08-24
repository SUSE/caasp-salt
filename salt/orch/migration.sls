{#- Get a list of nodes seem to be down or unresponsive #}
{#- This sends a "are you still there?" message to all #}
{#- the nodes and wait for a response, so it takes some time. #}

{%- set parallelism = salt['pillar.get']('parallelism', 3) %}

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

{%- set is_migratable = is_responsive_node_tgt + ' and G@tx_update_migration_available:true' %}

{%- set is_admin = is_migratable + ' and G@roles:admin' %}

{%- set nodes_up = salt.saltutil.runner('manage.up') %}

{% for node in nodes_up %}
  # Maybe using the cache here might lead to problems, if it is out of date.
  {%- set migration_grain = salt['saltutil.runner']('cache.grains', tgt=node)[node].get('tx_update_migration_available', false) %}
  {%- do salt.caasp_log.debug('Checking {0} for migration: {1}'.format(node, migration_grain)) %}
  {% if not migration_grain %}
    {% do salt.test.exception('Not all nodes are migratable: {0} is missing'.format(node)) %}
  {% endif %}
{% endfor %}

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
