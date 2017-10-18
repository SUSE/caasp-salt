include:
  - crypto

{% from '_macros/certs.jinja' import extra_names, extra_master_names, certs with context %}

{% set extra = extra_names() %}
{% if "kube-master" in salt['grains.get']('roles', []) %}
  {% set extra = extra_master_names() %}
{% endif %}

{{ certs("node:" + grains['caasp_fqdn'],
         pillar['ssl']['crt_file'],
         pillar['ssl']['key_file'],
         o = pillar['certificate_information']['subject_properties']['O'],
         extra = extra) }}
