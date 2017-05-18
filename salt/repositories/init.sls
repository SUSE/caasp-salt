{% if grains['oscodename'].startswith("openSUSE Leap") %}
/etc/zypp/repos.d/containers.repo:
  file.managed:
    - source: salt://repositories/containers.repo
    - order: 0
    - template: jinja
{% endif %}
