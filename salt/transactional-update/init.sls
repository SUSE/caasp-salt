{% if 'ca' not in salt['grains.get']('roles', []) %}
{% if not salt['grains.get']('update_in_progress')  %}
transactional-update.timer:
  service.running:
    - name: transactional-update.timer
    - enable: True
    - watch:
      - file: /etc/transactional-update.conf
{% endif %}

/etc/transactional-update.conf:
  file.managed:
    - source: salt://transactional-update/transactional-update.conf
{% else %}
{# See https://github.com/saltstack/salt/issues/14553 #}
transactional-update-dummy:
  cmd.run:
    - name: "echo saltstack bug 14553"

{% endif %}
