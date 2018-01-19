
# try to remove some dirs that could contain sensitive
# information, even when they were not directly managed by us

wipe-etc-kubernetes:
  cmd.run:
    - name: rm -rf /etc/kubernetes/*

wipe-certificates:
  cmd.run:
    - name: rm -rf /var/lib/ca-certificates/*

# remove some logs that could contain sensitive information
wipe-var-log:
  cmd.run:
    - name: |-
        for f in apparmor audit containers faillog firewall localmessages pods zypper.log YaST2 ; do
          rm -rf /var/log/$f
        done
  # NOTE: do not try to remove /var/log/salt
  #       or the Salt minion will crash...

# cleanup all the Salt things we can
# NOTE: we must be careful (or Salt will stop working)
cleanup-salt:
  service.disabled:
    - name: salt-minion
  # remove all the grains the hard way
  file.absent:
    - name: /etc/salt/grains
