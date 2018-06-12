{% if salt.caasp_pillar.get('addons:tiller', False) %}

wait-for-tiller-deployment:
  caasp_kubectl.wait_for_deployment:
    - name: tiller-deploy

{% else %}

tiller-deployment-wait-dummy:
  cmd.run:
    - name: echo "Tiller addon not enabled in config"

{% endif %}
