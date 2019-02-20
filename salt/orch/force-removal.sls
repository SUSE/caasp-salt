{#- Make sure we start with an updated mine #}
{%- set _ = salt.caasp_orch.sync_all() %}

{#- must provide the node (id) to be removed in the 'target' pillar #}
{%- set target = salt['pillar.get']('target') %}

{%- set super_master = salt.saltutil.runner('manage.up', tgt='G@roles:kube-master and not ' + target, expr_form='compound')|first %}

set-cluster-wide-removal-grain:
  salt.function:
    - tgt: '*'
    - name: grains.setval
    - arg:
      - force_removal_in_progress
      - true

update-modules:
  salt.function:
    - tgt: '*'
    - names:
      - saltutil.refresh_pillar
      - saltutil.refresh_grains
      - mine.update

sync-all:
  salt.function:
    - tgt: '*'
    - name: saltutil.sync_all
    - kwarg:
        refresh: True

unregister-{{ target }}:
  salt.state:
    - tgt: {{ super_master }}
    - sls:
        - etcd.remove
        - kubelet.remove-post-orchestration
    - fail_minions: {{ super_master }}
    - pillar:
        target: {{ target }}
        forced: True

cleanup-{{ target }}:
  salt.state:
    - tgt: {{ target }}
    - sls:
        - cleanup.etcd
    - fail_minions: {{ target }}
    - expect_minions: False
    - pillar:
        forced: True

remove-cluster-wide-removal-grain:
  salt.function:
    - tgt: '*'
    - name: grains.delval
    - arg:
      - force_removal_in_progress
    - kwarg:
        destructive: True

remove-target-mine:
  salt.function:
    - tgt: {{ target }}
    - name: mine.flush
    - fail_minions: {{ target }}
    - expect_minions: False

remove-target-salt-key:
  salt.wheel:
    - name: key.reject
    - include_accepted: True
    - match: {{ target }}
