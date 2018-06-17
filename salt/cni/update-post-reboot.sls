
/etc/cni/net.d/87-podman-bridge.conflist:
  file.absent
    # Has to be removed, otherwise kubernetes will use this CNI driver
    # instead of the flannel one.
    # Moreover, by doing that podman containers will be attached to the
    # flannel network, which is useful for debugging.
