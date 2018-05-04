{% set plugin = salt['pillar.get']('cni:plugin', 'cilium').lower() %}
{% if plugin == "cilium" %}

include:
  - ca-cert
  - cert
  - crypto

{% from '_macros/certs.jinja' import certs with context %}
{{ certs("cilium",
         pillar['ssl']['cilium_crt'],
         pillar['ssl']['cilium_key'],
         cn = grains['nodename'],
         o = 'system:nodes') }}

{% else %}
{# See https://github.com/saltstack/salt/issues/14553 #}
cni-cilium-dummy:
  cmd.run:
    - name: "echo saltstack bug 14553"
{% endif %}
