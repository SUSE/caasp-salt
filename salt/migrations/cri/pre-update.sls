# This state will completely remove /var/lib/container before a reboot.
# Otherwise a cri-o update might spin up a huge number of pause-containers,
# that will put this node into an unusable state.

# To remove the folder we have to:
# - Delete the btrfs subvolumes
# - Unmount the tmpfs filesystems
# - Unmount the btrfs storage pool
# - Remove the contents of the folder (the folder itself is readonly and can't be removed on our systems)

{% if salt.caasp_cri.cri_version().startswith("1.9.") %}

Cleanup crio pods:
  cmd.script:
    - source: salt://migrations/cri/clean-up-crio-pods.sh

{% else %}

{# See https://github.com/saltstack/salt/issues/14553 #}
cni-cleanup-dummy:
  cmd.run:
    - name: "echo saltstack bug 14553"

{% endif %}
