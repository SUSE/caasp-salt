coreutils:
  pkg:
    - installed

unmount-swaps:
  cmd.run:
    - name: /sbin/swapoff -a
    - onlyif: test `tail -n +2 /proc/swaps | wc -l` != 0

remove-swap-from-fstab:
  file.line:
    - name: /etc/fstab
    - content:
    - match: ' swap '
    - mode: delete
