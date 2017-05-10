{% set hostname = grains['id'] + '.' + pillar['internal_infra_domain'] %}

/etc/hostname:
  file.managed:
    - contents: {{ hostname }}
    - backup: false

hostname-static:
  cmd.run:
    - name: hostnamectl set-hostname --static --transient {{ hostname }}
    - unless: [[ $(hostnamectl --transient) == {{ hostname }} ]]
  module.run:
    - name: mine.update
