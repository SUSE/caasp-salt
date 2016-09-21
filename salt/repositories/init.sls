/etc/zypp/repos.d/obs_virtualization_containers.repo:
  file.managed:
    - source: salt://repositories/obs_virtualization_containers.repo
    - order: 0
    - template: jinja

{% if grains['lsb_distrib_codename'].startswith("SUSE Linux Enterprise Server 12") %}

/etc/zypp/repos.d/ibs_images_sles12sp2.repo:
  file.managed:
    - source: salt://repositories/ibs_images_sles12sp2.repo
    - order: 1
    - template: jinja

/etc/zypp/repos.d/ibs_devel_docker.repo:
  file.managed:
    - source: salt://repositories/ibs_devel_docker.repo
    - order: 2
    - template: jinja

{% endif %}

# Our SLE repositories don't trust the repositories added by IBS
# for some reason...
/etc/zypp/zypp.conf:
  file.append:
    - text: "gpgcheck = off"
    - order: 1
