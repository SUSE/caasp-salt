# cleanup all the things we have created

{%- set name = 'node:' + grains['nodename'] %}
/etc/pki/private/{{ name }}-bundle.pem:
  file.absent

{{ pillar['ssl']['kubelet_crt'] }}:
  file.absent

{{ pillar['ssl']['kubelet_key'] }}:
  file.absent

/etc/kubernetes/kubelet-initial:
  file.absent

{{ pillar['paths']['kubelet_config'] }}:
  file.absent

{% if salt.caasp_pillar.get('cloud:provider') == 'openstack' %}
/etc/kubernetes/openstack-config:
  file.absent
{% endif %}
