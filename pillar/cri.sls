cri:
  chosen: 'docker'
  socket_timeout: 20
  docker:
    description: Docker open-source container engine
    package: docker
    service: docker
    socket: /var/run/dockershim.sock
  crio:
    description: CRI-O
    package: cri-o
    service: crio
    socket: /var/run/crio/crio.sock
    dirs:
      root: /var/lib/containers/storage
      runroot: /var/lib/containers/storage
