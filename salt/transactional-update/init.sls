{# In devenv, the transactional-update service does not exist on admin #}
{% if salt['grains.get']('virtual_subtype', None) != 'Docker' %}
/etc/systemd/system/transactional-update.service.d/10-update-rebootmgr-options.conf:
  file.managed:
    - makedirs: true
    - source: salt://transactional-update/10-update-rebootmgr-options.conf
    - user: root
    - group: root
    - mode: 644

/etc/systemd/system/transactional-update.timer.d/10-increase-update-speed.conf:
  file.managed:
    - makedirs: true
    - template: jinja
    - source: salt://transactional-update/10-increase-update-speed.conf.jinja
    - user: root
    - group: root
    - mode: 644

service.systemctl_reload:
  module.run:
    - onchanges:
      - file: /etc/systemd/system/transactional-update.service.d/10-update-rebootmgr-options.conf
      - file: /etc/systemd/system/transactional-update.timer.d/10-increase-update-speed.conf

transactional-update.timer:
  service.running:
    - name: transactional-update.timer
    - enable: True
    - watch:
      - file: /etc/systemd/system/transactional-update.timer.d/10-increase-update-speed.conf
{% else %}
{# See https://github.com/saltstack/salt/issues/14553 #}
transactional_update_dummy_step:
  cmd.run:
    - name: "echo saltstack bug 14553"
{% endif %}

