#!/bin/bash

set -x

. ./set-env.sh

kubectl config set-context $CLUSTER1_NAME
kubectl config use-context $CLUSTER1_NAME

kubectl delete -n $NAMESPACE_DEPARTMENT deployment department
kubectl delete -n $NAMESPACE_DEPARTMENT secret department
kubectl delete -n $NAMESPACE_DEPARTMENT configmap department
kubectl delete -n $NAMESPACE_DEPARTMENT service department

kubectl delete -n $NAMESPACE_GATEWAY deployment gateway
kubectl delete -n $NAMESPACE_GATEWAY service gateway
kubectl delete -n $NAMESPACE_GATEWAY configmap gateway
kubectl delete -n $NAMESPACE_GATEWAY ingress gateway-ingress

kubectl delete -n $NAMESPACE_ORGANIZATION deployment organization
kubectl delete -n $NAMESPACE_ORGANIZATION service organization
kubectl delete -n $NAMESPACE_ORGANIZATION secret organization
kubectl delete -n $NAMESPACE_ORGANIZATION configmap organization

kubectl delete -n $NAMESPACE_EMPLOYEE deployment employee
kubectl delete -n $NAMESPACE_EMPLOYEE service employee
kubectl delete -n $NAMESPACE_EMPLOYEE secret employee
kubectl delete -n $NAMESPACE_EMPLOYEE configmap employee








