#!/bin/bash

set -e

KUBECTL_PATH="${KUBECTL_PATH:-/usr/bin/kubectl}"

# dir where manifests are
DIR=/etc/kubernetes/addons

############################################################################

abort() { echo "FATAL: $@" ; exit 1 ; }

NS_ARGS="--namespace=kube-system"
SRV_ARGS="--server=http://127.0.0.1:8080"

# Each kubectl command is potentially ran twice, as `apply -f` is not truly
# idempotant. The "create or update" logic is client side, so there is a check
# + set race condition. If it fails, we try it again, if it fails again, we will
# fail the entire execution of this script. This works around the "create or update"
# check+set race.

echo "Creating kube-system namespace..."
# use kubectl to create kube-system namespace
NAMESPACE=`eval "$KUBECTL_PATH $SRV_ARGS get namespaces | grep kube-system | cat"`
if [ ! "$NAMESPACE" ]; then
	$KUBECTL_PATH $SRV_ARGS apply -f "$DIR/namespace.yaml" || $KUBECTL_PATH $SRV_ARGS apply -f "$DIR/namespace.yaml"
	echo "The namespace 'kube-system' is successfully created."
else
	echo "The namespace 'kube-system' is already there. Skipping."
fi

echo "Deploying DNS on Kubernetes"

KUBEDNS_SA=`eval "$KUBECTL_PATH $NS_ARGS $SRV_ARGS get sa | grep kube-dns | cat"`
if [ ! "$KUBEDNS_SA" ]; then
	# use kubectl to create kubedns service account
	$KUBECTL_PATH $NS_ARGS $SRV_ARGS apply -f "$DIR/kubedns-sa.yaml" || $KUBECTL_PATH $NS_ARGS $SRV_ARGS apply -f "$DIR/kubedns-sa.yaml"

	echo "Kube-dns service account successfully created."
else
	echo "Kube-dns service account  already there. Skipping."
fi

KUBEDNS_CM=`eval "$KUBECTL_PATH $NS_ARGS $SRV_ARGS get cm | grep kube-dns | cat"`
if [ ! "$KUBEDNS_CM" ]; then
	# use kubectl to create kubedns config map
	$KUBECTL_PATH $NS_ARGS $SRV_ARGS apply -f "$DIR/kubedns-cm.yaml" || $KUBECTL_PATH $NS_ARGS $SRV_ARGS apply -f "$DIR/kubedns-cm.yaml"

	echo "Kube-dns config map successfully created."
else
	echo "Kube-dns config map already there. Skipping."
fi

KUBEDNS=`eval "$KUBECTL_PATH $NS_ARGS $SRV_ARGS get deployment | grep kube-dns | cat"`
if [ ! "$KUBEDNS" ]; then
	# use kubectl to create kubedns deployment
	$KUBECTL_PATH $NS_ARGS $SRV_ARGS apply -f "$DIR/kubedns.yaml" || $KUBECTL_PATH $NS_ARGS $SRV_ARGS apply -f "$DIR/kubedns.yaml"

	echo "Kube-dns successfully deployed."
else
	echo "Kube-dns already deployed. Skipping."
fi

KUBEDNS_SVC=`eval "$KUBECTL_PATH $NS_ARGS $SRV_ARGS get svc | grep kube-dns | cat"`
if [ ! "$KUBEDNS_SVC" ]; then
	# use kubectl to create kubedns service
	$KUBECTL_PATH $NS_ARGS $SRV_ARGS apply -f "$DIR/kubedns-svc.yaml" || $KUBECTL_PATH $NS_ARGS $SRV_ARGS apply -f "$DIR/kubedns-svc.yaml"

	echo "Kube-dns service successfully created."
else
	echo "Kube-dns service already there. Skipping."
fi

echo

