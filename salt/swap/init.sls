coreutils:
  pkg:
    - installed

unmount-swaps:
  cmd.run:
    - name: /sbin/swapoff -a

remove-swap-from-fstab:
  file.line:
    - name: /etc/fstab
    - content:
    - match: ' swap '
    - mode: delete
