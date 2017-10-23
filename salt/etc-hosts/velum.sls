# Velum container will not see any updates of the /etc/hosts. It can't be fixed with bind-mount
# of /etc/hosts in the container, because of fileblock.replace copies the new file over the old /etc/hosts.
# So the old /etc/hosts will remain mounted in the container (as bind-mount works at inode level).
# For more info see https://github.com/kubic-project/salt/pull/265#issuecomment-337256898
{% if "admin" in salt['grains.get']('roles', []) %}
update-velum:
  cmd.run:
    - name: |-
        velum_id=$( docker ps | grep velum-dashboard | awk '{print $1}')
        if [ -n "$velum_id" ]; then
            docker cp /etc/hosts $velum_id:/etc/hosts
        fi
{% endif %}
