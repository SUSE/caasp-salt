# cleanup all the things we have created

node-pem:
  cmd.run:
    - name: rm -f /etc/pki/private/node*.pem

{{ pillar['ssl']['kubelet_crt'] }}:
  file.absent

{{ pillar['ssl']['kubelet_key'] }}:
  file.absent

# this file can contain sensitive information, so it must be removed too
{{ pillar['paths']['kubelet_config'] }}:
  file.absent

# and this one too
/etc/kubernetes/openstack-config:
  file.absent
