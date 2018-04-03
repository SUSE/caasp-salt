{% if salt.caasp_pillar.get('addons:tiller', False) %}

{% from '_macros/kubectl.jinja' import kubectl_wait_for_deployment with context %}

{{ kubectl_wait_for_deployment('tiller-deploy') }}

{% else %}

dummy:
  cmd.run:
    - name: echo "Tiller addon not enabled in config"

{% endif %}
