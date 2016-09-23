/etc/zypp/repos.d/containers.repo:
  file.managed:
    - source: salt://repositories/containers.repo
    - order: 0
    - template: jinja

# Our SLE repositories don't trust the repositories added by IBS
# for some reason...
/etc/zypp/zypp.conf:
  file.append:
    - text: "gpgcheck = off"
    - order: 1
