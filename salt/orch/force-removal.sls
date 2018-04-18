# must provide the node (id) to be removed in the 'target' pillar
{%- set target = salt['pillar.get']('target') %}

{%- set super_master = salt.saltutil.runner('manage.up', tgt='G@roles:kube-master and not ' + target, expr_form='compound')|first %}

set-cluster-wide-removal-grain:
  salt.function:
    - tgt: '*'
    - name: grains.setval
    - arg:
      - force_removal_in_progress
      - true

sync-all:
  salt.function:
    - tgt: '*'
    - names:
      - saltutil.refresh_pillar
      - saltutil.refresh_grains
      - mine.update
      - saltutil.sync_all

unregister-{{ target }}:
  salt.state:
    - tgt: {{ super_master }}
    - sls:
        - cleanup.remove-post-orchestration
    - fail_minions: {{ super_master }}
    - pillar:
        target: {{ target }}
        forced: True

remove-cluster-wide-removal-grain:
  salt.function:
    - tgt: '*'
    - name: grains.delval
    - arg:
      - force_removal_in_progress
    - kwarg:
        destructive: True

remove-target-salt-key:
  salt.wheel:
    - name: key.reject
    - include_accepted: True
    - match: {{ target }}
