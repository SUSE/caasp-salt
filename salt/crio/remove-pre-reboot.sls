# cleanup all the things we have created

/etc/systemd/system/kubelet.service.d/kubelet.conf:
  file.absent

/var/lib/containers/storage:
  cmd.run:
    - name: |-
        for subvolume in {{pillar['crio']['dirs']['root']}}/btrfs/subvolumes/* ; do
          btrfs subvolume delete $subvolume
        done
        rm -rf {{pillar['crio']['dirs']['root']}}*
        rm -rf {{pillar['crio']['dirs']['runroot']}}*
