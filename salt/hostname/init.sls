caasp_fqdn:
  grains.present:
    - value: {{ grains['id'] }}.{{ pillar['internal_infra_domain'] }}
