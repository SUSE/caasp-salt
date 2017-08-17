#!/bin/bash

set -e

KUBECTL_PATH="${KUBECTL_PATH:-/usr/bin/kubectl}"

# dir where manifests are
DIR=/etc/kubernetes/addons

############################################################################

abort() { echo "FATAL: $@" ; exit 1 ; }

NS_ARGS="--namespace=kube-system"
SRV_ARGS="--server=http://127.0.0.1:8080"

echo "Creating kube-system namespace..."
# use kubectl to create kube-system namespace
NAMESPACE=`eval "$KUBECTL_PATH $SRV_ARGS get namespaces | grep kube-system | cat"`
if [ ! "$NAMESPACE" ]; then
	$KUBECTL_PATH $SRV_ARGS create -f "$DIR/namespace.yaml"
	echo "The namespace 'kube-system' is successfully created."
else
	echo "The namespace 'kube-system' is already there. Skipping."
fi

echo "Deploying DNS on Kubernetes"

KUBEDNS_SA=`eval "$KUBECTL_PATH $NS_ARGS $SRV_ARGS get sa | grep kube-dns | cat"`
if [ ! "$KUBEDNS_SA" ]; then
	# use kubectl to create kubedns service account
	$KUBECTL_PATH $NS_ARGS $SRV_ARGS create -f "$DIR/kubedns-sa.yaml"

	echo "Kube-dns service account successfully created."
else
	echo "Kube-dns service account  already there. Skipping."
fi

KUBEDNS_CM=`eval "$KUBECTL_PATH $NS_ARGS $SRV_ARGS get cm | grep kube-dns | cat"`
if [ ! "$KUBEDNS_CM" ]; then
	# use kubectl to create kubedns config map
	$KUBECTL_PATH $NS_ARGS $SRV_ARGS create -f "$DIR/kubedns-cm.yaml"

	echo "Kube-dns config map successfully created."
else
	echo "Kube-dns config map already there. Skipping."
fi

KUBEDNS=`eval "$KUBECTL_PATH $NS_ARGS $SRV_ARGS get deployment | grep kube-dns | cat"`
if [ ! "$KUBEDNS" ]; then
	# use kubectl to create kubedns deployment
	$KUBECTL_PATH $NS_ARGS $SRV_ARGS create -f "$DIR/kubedns.yaml"

	echo "Kube-dns successfully deployed."
else
	echo "Kube-dns already deployed. Skipping."
fi

KUBEDNS_SVC=`eval "$KUBECTL_PATH $NS_ARGS $SRV_ARGS get svc | grep kube-dns | cat"`
if [ ! "$KUBEDNS_SVC" ]; then
	# use kubectl to create kubedns service
	$KUBECTL_PATH $NS_ARGS $SRV_ARGS create -f "$DIR/kubedns-svc.yaml"

	echo "Kube-dns service successfully created."
else
	echo "Kube-dns service already there. Skipping."
fi

echo

