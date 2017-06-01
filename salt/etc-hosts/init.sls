/etc/hosts:
  file.blockreplace:
    - marker_start: "#-- start Salt-CaaSP managed hosts - DO NOT MODIFY --"
    - marker_end:   "#-- end Salt-CaaSP managed hosts --"
    - source:       salt://etc-hosts/hosts.jinja
    - template:     jinja
    - append_if_not_found: True
