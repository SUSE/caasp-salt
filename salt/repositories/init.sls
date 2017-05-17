/etc/zypp/repos.d/containers.repo:
  file.managed:
    - source: salt://repositories/containers.repo
    - order: 0
    - template: jinja
{% if not grains['oscodename'].startswith("openSUSE Leap") %}
    - create: False
{% endif %}
