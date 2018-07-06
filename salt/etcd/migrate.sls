/tmp/create-or-update-etcd-pillar:
  file.managed:
    - source: salt://etcd/create-or-update-etcd-pillar.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: 755

create-or-update-etcd-pillar:
  cmd.run:
    - name: python /tmp/create-or-update-etcd-pillar
    - require:
      - file: /tmp/create-or-update-etcd-pillar
