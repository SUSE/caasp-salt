#!/bin/bash

for c in $(runc list -q); do
    output=$(runc state $c | grep io.kubernetes.cri-o.ContainerType)
    if [[ "$output" =~ "container" ]]; then
        runc delete -f $c
    fi
    for m in $(mount | grep $c | awk '{print $3}'); do
        umount -R $m
    done
done

for c in $(runc list -q); do
    output=$(runc state $c | grep io.kubernetes.cri-o.ContainerType)
    if [[ "$output" =~ "sandbox" ]]; then
        runc delete -f $c
    fi
    for m in $(mount | grep $c | awk '{print $3}'); do
        umount -R $m
    done
done

# Remove the btrfs subvolumes under /var/lib/containers/storage/
for m in $(btrfs subvolume list / | grep /var/lib/containers/storage/btrfs/subvolumes | awk '{print $9}'); do
    # The subvolumes will have the @ prefix which we have to remove to delete them
    btrfs subvolume delete ${m#@}
done

umount -R /var/lib/containers/storage/btrfs
rm -rf /var/lib/containers/storage/*

# We nuke the /var/lib/containers/* here as the file.absent file module will
# fail on the read-only root folder /var/lib/containers/
rm -rf /var/lib/containers/*
