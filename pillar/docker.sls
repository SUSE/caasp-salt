docker:
  pkg: 'docker-kubic'
  daemon:
    # this mirrors the structure in /etc/docker/daemon.json
    iptables: 'false'
    log_level: 'warn'
