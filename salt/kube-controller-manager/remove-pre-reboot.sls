# cleanup all the things we have created

/etc/pki/private/kube-controller-manager-bundle.pem:
  file.absent

{{ pillar['ssl']['kube_controller_mgr_crt'] }}:
  file.absent

{{ pillar['ssl']['kube_controller_mgr_key'] }}:
  file.absent

{{ pillar['paths']['service_account_key'] }}:
  file.absent

{{ pillar['paths']['kube_controller_mgr_config'] }}:
  file.absent
