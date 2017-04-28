#######################
# config files
#######################

{{ pillar['paths']['kubeconfig'] }}:
  file.managed:
    - source:         salt://kubeconfig/kubeconfig.jinja
      template:       jinja
    