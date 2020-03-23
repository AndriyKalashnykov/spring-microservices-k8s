#!/bin/bash

#set -x

. ./set-env.sh

kubectl config set-context $CLUSTER1_NAME
kubectl config use-context $CLUSTER1_NAME

# this will only work if Employee Docker image build  from non-distroless image, see employee-exec.sh
kubectl get pod -n $NAMESPACE_EMPLOYEE -l 'app=employee' --no-headers | awk '{print $1}' | xargs -I {} sh -c  "kubectl exec -t {} -n \"$NAMESPACE_EMPLOYEE\" -- cat /etc/resolv.conf"


