{# In devenv, the rebootmgr service does not exist on admin #}
{% if salt['grains.get']('virtual_subtype', None) != 'Docker' %}
rebootmgr:
  service.dead:
    - enable: False
{% else %}
{# See https://github.com/saltstack/salt/issues/14553 #}
rebootmgr_dummy_step:
  cmd.run:
    - name: "echo saltstack bug 14553"
{% endif %}
