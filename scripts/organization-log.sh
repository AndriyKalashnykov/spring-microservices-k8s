#!/bin/bash

set -x

. ./set-env.sh

kubectl config set-context $CLUSTER1_NAME
kubectl config use-context $CLUSTER1_NAME

kubectl get pod -n $NAMESPACE_ORGANIZATION -l 'app=organization' --no-headers | awk '{print $1}' | xargs -I {} sh -c 'echo {}; kubectl logs --follow {} -n $NAMESPACE_ORGANIZATION'