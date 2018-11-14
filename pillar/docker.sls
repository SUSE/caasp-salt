docker:
  pkg: 'docker-kubic'
  daemon:
    # this mirrors the structure in /etc/docker/daemon.json
    iptables: 'false'
    log_level: 'warn'
    log_driver: 'json-file'
    log_max_size: '10m'
    log_max_file: '5'
