/etc/zypp/repos.d/obs_virtualization_containers.repo:
  file.managed:
    - source: salt://repositories/obs_virtualization_containers.repo
    - order: 0
