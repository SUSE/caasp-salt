# Remove our /etc/hosts entries, so that Systemd/Wicked hostname
# logic doesn't pick up out /etc/hosts entry names.
/etc/hosts:
  file.blockreplace:
    # If markers are changed, also update etc-hosts/init.sls
    - marker_start: "#-- start Salt-CaaSP managed hosts - DO NOT MODIFY --"
    - marker_end:   "#-- end Salt-CaaSP managed hosts --"
    - content:      ""
