beacons:
  network_settings:
    interval: 5
    # monitorize any change in IP addresses in any network interface
    # FIXME: add a way to only notify IP address changes on the default network interface
    '*':
      ipaddr:
