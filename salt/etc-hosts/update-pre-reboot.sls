# Remove our /etc/hosts entries, so that Systemd/Wicked hostname
# logic doesn't pick up out /etc/hosts entry names.
/etc/hosts:
  file.managed:
    - contents: |
        127.0.0.1	localhost

        # special IPv6 addresses
        ::1             localhost ipv6-localhost ipv6-loopback

        fe00::0         ipv6-localnet

        ff00::0         ipv6-mcastprefix
        ff02::1         ipv6-allnodes
        ff02::2         ipv6-allrouters
        ff02::3         ipv6-allhosts
