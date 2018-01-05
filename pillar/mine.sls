mine_functions:
  network.ip_addrs: []
  network.interfaces: []
  network.default_route: []
  nodename:
    - mine_function: grains.get
    - nodename
  host:
    - mine_function: grains.get
    - host
