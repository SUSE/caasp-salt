# (Re)Start and enable the docker daemon
docker:
  service.running:
    - restart: True
    - enable: True
