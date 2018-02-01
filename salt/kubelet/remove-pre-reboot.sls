# cleanup all the things we have created

node-pem:
  cmd.run:
    - name: rm -f /etc/pki/private/node*.pem

{{ pillar['ssl']['kubelet_crt'] }}:
  file.absent

{{ pillar['ssl']['kubelet_key'] }}:
  file.absent

/etc/kubernetes/kubelet-initial:
  file.absent

{{ pillar['paths']['kubelet_config'] }}:
  file.absent

/etc/kubernetes/openstack-config:
  file.absent

wipe-var-lib-kubelet:
  cmd.run:
    - name: |-
        mnts=`mount | grep kubelet | grep tmpfs | cut -f3 -d" "`
        for i in $mnts ; do
            umount $i
        done
        rm -rf /var/lib/kubelet/*
