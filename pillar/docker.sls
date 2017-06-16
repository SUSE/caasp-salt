docker:
  pkg: 'docker_1_12_6'
  daemon:
    # this mirrors the structure in /etc/docker/daemon.json
    iptables: 'false'
    log_level: 'warn'
