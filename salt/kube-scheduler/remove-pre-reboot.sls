# cleanup all the things we have created

/etc/pki/private/kube-scheduler-bundle.pem:
  file.absent

{{ pillar['ssl']['kube_scheduler_crt'] }}:
  file.absent

{{ pillar['ssl']['kube_scheduler_key'] }}:
  file.absent

{{ pillar['paths']['kube_scheduler_config'] }}:
  file.absent
