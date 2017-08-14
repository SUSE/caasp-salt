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

echo
