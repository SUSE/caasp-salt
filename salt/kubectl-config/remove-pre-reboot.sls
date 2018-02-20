# cleanup all the things we have created

{{ pillar['ssl']['kubectl_crt'] }}:
  file.absent

{{ pillar['ssl']['kubectl_key'] }}:
  file.absent

{{ pillar['paths']['kubeconfig'] }}:
  file.absent

/root/.kube:
  file.absent
