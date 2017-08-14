#!/bin/bash

set -e

KUBECTL_PATH="${KUBECTL_PATH:-/usr/bin/kubectl}"

# dir where manifests are
DIR=/etc/kubernetes/addons

############################################################################

abort() { echo "FATAL: $@" ; exit 1 ; }

NS_ARGS="--namespace=kube-system"
SRV_ARGS="--server=http://127.0.0.1:8080"

echo "Deploying tiller on Kubernetes"

TILLER=`eval "$KUBECTL_PATH $NS_ARGS $SRV_ARGS get deployment | grep tiller | cat"`
if [ ! "$TILLER" ]; then
	# use kubectl to create tiller deployment
	$KUBECTL_PATH $NS_ARGS $SRV_ARGS create -f "$DIR/tiller.yaml"

	echo "Tiller successfully deployed."
else
	echo "Tiller already deployed. Skipping."
fi

TILLER_SVC=`eval "$KUBECTL_PATH $NS_ARGS $SRV_ARGS get svc | grep tiller | cat"`
if [ ! "$TILLER_SVC" ]; then
	# use kubectl to create tiller service
	$KUBECTL_PATH $NS_ARGS $SRV_ARGS create -f "$DIR/tiller-svc.yaml"

	echo "Tiller service successfully created."
else
	echo "Tiler service already there. Skipping."
fi

echo

