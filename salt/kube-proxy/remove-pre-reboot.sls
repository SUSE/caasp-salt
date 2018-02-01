# cleanup all the things we have created

/etc/pki/private/kube-proxy-bundle.pem:
  file.absent

{{ pillar['ssl']['kube_proxy_crt'] }}:
  file.absent

{{ pillar['ssl']['kube_proxy_key'] }}:
  file.absent

{{ pillar['paths']['kube_proxy_config'] }}:
  file.absent
