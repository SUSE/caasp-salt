mine_functions:
  network.ip_addrs: [eth0]
  hostname:
    - mine_function: grains.get
    - nodename
