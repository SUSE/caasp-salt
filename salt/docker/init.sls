docker:
  pkg.installed:
    - install_recommends: False
    - require:
      - file: /etc/zypp/repos.d/obs_virtualization_containers.repo
  service.running:
    - enable: True
    - watch:
      - service: flannel
    - require:
      - pkg: docker

{% if grains['lsb_distrib_codename'].startswith("SUSE Linux Enterprise Server 12") %}

kubernetes-node-image-pause:
  pkg.installed:
    - install_recommends: False
    - require:
      - file: /etc/zypp/repos.d/ibs_devel_docker.repo

build-pause-image:
  cmd.wait:
    - name: docker build -t suse/pause:latest .
    - cwd: /usr/share/suse-docker-images/pause
    - require:
      - pkg: kubernetes-node-image-pause
      - service: docker
    - watch:
      - pkg: kubernetes-node-image-pause

# TODO: remove rpm once the image has been activated by sle2docker
sles12sp2-docker-image:
  pkg.installed:
    - install_recommends: False
    - require:
      - file: /etc/zypp/repos.d/ibs_images_sles12sp2.repo

# TODO: remove sle2docker package once image has been activated
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
