#!/bin/bash

set -uo pipefail

# Preseeds a node in Kubernetes with critical data migrated from
# an old node.

OLD_NODE_NAME="$1"
NEW_NODE_NAME="$2"

##########################################################

log() { echo "[machine-id migration]: $1 " ; logger -t "machine-id-migration" "$1" ; }

exit_changes() {
	log "$2"
	echo  # an empty line here so the next line will be the last.
	echo "changed=$1 comment='"$2"'"
	exit 0
}

get_node_data() {
	local template="$1"
	kubectl get node "$OLD_NODE_NAME" --template="{{$template}}"
}

##########################################################

log "migrating $OLD_NODE_NAME to $NEW_NODE_NAME"

kubectl get node $OLD_NODE_NAME || exit_changes "no" "$OLD_NODE_NAME does not exist, nothing to migrate"

cat << EOF > /tmp/k8s-node-migration.yaml
apiVersion: v1
kind: Node
metadata:
  name: ${NEW_NODE_NAME}
  labels:
    kubernetes.io/hostname: '$(get_node_data 'index .metadata.labels "kubernetes.io/hostname"')'
    beta.kubernetes.io/arch: '$(get_node_data 'index .metadata.labels "beta.kubernetes.io/arch"')'
    beta.kubernetes.io/os: '$(get_node_data 'index .metadata.labels "beta.kubernetes.io/os"')'
  annotations:
    node.alpha.kubernetes.io/ttl: '$(get_node_data 'index .metadata.annotations "node.alpha.kubernetes.io/ttl"')'
    volumes.kubernetes.io/controller-managed-attach-detach: '$(get_node_data 'index .metadata.annotations "volumes.kubernetes.io/controller-managed-attach-detach"')'
    flannel.alpha.coreos.com/backend-data: '$(get_node_data 'index .metadata.annotations "flannel.alpha.coreos.com/backend-data"')'
    flannel.alpha.coreos.com/backend-type: '$(get_node_data 'index .metadata.annotations "flannel.alpha.coreos.com/backend-type"')'
    flannel.alpha.coreos.com/public-ip: $(get_node_data 'index .metadata.annotations "flannel.alpha.coreos.com/public-ip"')
    flannel.alpha.coreos.com/kube-subnet-manager: "true"
spec:
  externalID: ${NEW_NODE_NAME}
  podCIDR: $(get_node_data .spec.podCIDR)
EOF

kubectl create -f /tmp/k8s-node-migration.yaml 2>/dev/null

rm /tmp/k8s-node-migration.yaml

exit_changes "yes" "Node data migrated from $OLD_NODE_NAME to $NEW_NODE_NAME"
