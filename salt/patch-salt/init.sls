remount-rw:
  cmd.run:
    - name: |-
        btrfs property set -ts /.snapshots/1/snapshot ro false
        mount -o remount,rw /
    - check_cmd:
      - /bin/true

patch-x509:
  file.managed:
    - name:   /usr/lib/python2.7/site-packages/salt/modules/publish.py
    - source: salt://patch-salt/publish.py