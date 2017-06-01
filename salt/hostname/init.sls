caasp_fqdn:
  grains.present:
    - value: {{ grains['id'] }}.{{ pillar['internal_infra_domain'] }}

# Both of the below are due to be removed, and can't use the `caasp_fqdn` grain
# as it's not available in grains until the next state, so lets leave them as is
# for the moment
/etc/hostname:
  file.managed:
    - contents: {{ grains['id'] }}.{{ pillar['internal_infra_domain'] }}
    - backup: false
    - require:
      - grains: caasp_fqdn

hostname-static:
  cmd.run:
    - name: hostnamectl set-hostname --static --transient {{ grains['id'] }}.{{ pillar['internal_infra_domain'] }}
    - unless: [[ $(hostnamectl --transient) == {{ grains['id'] }}.{{ pillar['internal_infra_domain'] }} ]]
    - require:
        - grains: caasp_fqdn
  module.run:
    - name: mine.update
