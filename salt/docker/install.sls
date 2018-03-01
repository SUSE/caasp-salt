include:
  - repositories

docker:
  pkg.installed:
    - name: {{ salt.caasp_pillar.get('docker:pkg', 'docker') }}
    - install_recommends: False
    - require:
      - file: /etc/zypp/repos.d/containers.repo
