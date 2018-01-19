# cleanup all the things we have created

/etc/systemd/system/docker.service.d/proxy.conf:
  file.absent

/etc/docker/daemon.json:
  file.absent

/etc/sysconfig/docker:
  file.absent

/etc/docker/certs.d:
  file.absent

/var/lib/docker:
  cmd.run:
    - name: |-
        for subvolume in /var/lib/docker/btrfs/subvolumes/* ; do
          btrfs subvolume delete $subvolume
        done
        rm -rf /var/lib/docker/*
