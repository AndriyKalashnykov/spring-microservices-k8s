#!/bin/bash

set -x

.  ./set-env.sh

kubectl config set-context $CLUSTER1_NAME
kubectl config use-context $CLUSTER1_NAME

kubectl delete -n $NAMESPACE_MONGO deployment mongodb
kubectl delete -n $NAMESPACE_MONGO service mongodb
kubectl delete -n $NAMESPACE_MONGO configmap mongodb
kubectl delete -n $NAMESPACE_MONGO secret mongodb
