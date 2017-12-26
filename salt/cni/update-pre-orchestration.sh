#!/bin/sh

NODE_ID="$1"
EXTERNAL_IP="$2"
BACKEND_TYPE="$3"

FLANNEL_STATE_FILE="/run/flannel/subnet.env"

##########################################################

log() { echo "[CNI migration]: $1 " ; logger -t "cni-migration" "$1" ; }

exit_changes() {
	log "$2"
	echo  # an empty line here so the next line will be the last.
	echo "changed=$1 comment='"$2"'"
	exit 0
}

get_node_cidr() {
	kubectl get no "$NODE_ID" --template="{{.spec.podCIDR}}"
}

patch_node() {
	kubectl patch node $NODE_ID -p "$@" 2>/dev/null
}

##########################################################

log "migrating $NODE_ID CIDR"

[ -e "$FLANNEL_STATE_FILE" ] || exit_changes "no" "no flannel state file found"
source $FLANNEL_STATE_FILE
old_node_cidr=$(echo "$FLANNEL_SUBNET" | sed -e "s/\.1\//\.0\//g")
log "flannel state file found with node CIDR=$old_node_cidr"

curr_node_cidr=$(get_node_cidr)
if [ -n "$curr_node_cidr" ] && [ "$curr_node_cidr" != "<no value>" ] ; then
       exit_changes "no" "node already has a podCIDR:$curr_node_cidr"
fi

log "$NODE_ID does not have a CIDR assigned: setting $old_node_cidr"
patch_node "{\"spec\":{\"podCIDR\":\"$old_node_cidr\"}}"
curr_node_cidr=$(get_node_cidr)

log "adding some annotations..."
patch_node "{\"metadata\":{\"annotations\":{\"alpha.kubernetes.io/provided-node-ip\": \"$EXTERNAL_IP\"}}}"
patch_node "{\"metadata\":{\"annotations\":{\"flannel.alpha.coreos.com/public-ip\": \"$EXTERNAL_IP\"}}}"
patch_node "{\"metadata\":{\"annotations\":{\"flannel.alpha.coreos.com/kube-subnet-manager\": true}}}"
patch_node "{\"metadata\":{\"annotations\":{\"flannel.alpha.coreos.com/backend-type\": \"$BACKEND_TYPE\"}}}"
exit_changes "yes" "new CIDR set for $NODE_ID podCIDR:$curr_node_cidr"
