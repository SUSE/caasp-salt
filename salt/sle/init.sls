{% if grains['lsb_distrib_codename'].startswith("SUSE Linux Enterprise Server 12") %}

##
# Repositories that are required in SLE

/etc/zypp/repos.d/ibs_images_sles12sp2.repo:
  file.managed:
    - source: salt://repositories/ibs_images_sles12sp2.repo
    - order: 1
    - template: jinja

##
# Packages only installed in SLE

kubernetes-node-image-pause:
  pkg.installed:
    - install_recommends: False
    - require:
      - file: /etc/zypp/repos.d/containers.repo

build-pause-image:
  cmd.wait:
    - name: docker build -t suse/pause:latest .
    - cwd: /usr/share/suse-docker-images/pause
    - require:
      - pkg: kubernetes-node-image-pause
      - service: docker
    - watch:
      - pkg: kubernetes-node-image-pause

sles12sp2-docker-image:
  pkg.installed:
    - install_recommends: False
    - require:
      - file: /etc/zypp/repos.d/ibs_images_sles12sp2.repo

sle2docker:
  pkg.installed:
    - install_recommends: False
    - require:
      - pkg: sles12sp2-docker-image

run-sle2docker:
  cmd.wait:
    - name: sle2docker activate $(sle2docker list | tail -n -1 | awk '{ print $2 }')
    - require:
      - pkg: sle2docker
      - service: docker
    - watch:
      - pkg: sle2docker

{% endif %}
