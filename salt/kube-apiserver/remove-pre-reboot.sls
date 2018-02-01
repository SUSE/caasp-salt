# cleanup all the things we have created

/etc/pki/private/kube-apiserver-bundle.pem:
  file.absent

{{ pillar['ssl']['kube_apiserver_crt'] }}:
  file.absent

{{ pillar['ssl']['kube_apiserver_key'] }}:
  file.absent

/etc/kubernetes/apiserver:
  file.absent
