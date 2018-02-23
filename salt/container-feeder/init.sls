include:
  - docker

# bsc#1040579: if docker was not running before container-feeder, then it will
# fail silently. Instead, after enabling docker, restart container-feeder so it
# works even in that case.
#
# TODO: we should ensure that this is also guaranteed at the OS level.
container-feeder:
  service.running:
    - enable: True
    - require:
      - cmd: docker
    - watch:
      - service: docker
