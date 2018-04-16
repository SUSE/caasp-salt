
# try to remove some dirs that could contain sensitive
# information, even when they were not directly managed by us

wipe-certificates:
  cmd.run:
    - name: rm -rf /var/lib/ca-certificates/*

# cleanup all the Salt things we can
# NOTE: we must be careful (or Salt will stop working)
cleanup-salt:
  service.disabled:
    - name: salt-minion
  # remove all the grains the hard way
  file.absent:
    - name: /etc/salt/grains
