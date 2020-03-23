#!/bin/bash

#set -e
set -x

. ./set-env.sh

kubectl config set-context $CLUSTER1_NAME
kubectl config use-context $CLUSTER1_NAME

kubectl create namespace $NAMESPACE_DEPARTMENT
kubectl create namespace $NAMESPACE_EMPLOYEE
kubectl create namespace $NAMESPACE_GATEWAY
kubectl create namespace $NAMESPACE_ORGANIZATION
kubectl create namespace $NAMESPACE_MONGO

kubectl apply  -f ../k8s/rbac-cluster-role.yaml

kubectl create clusterrolebinding service-pod-reader-$NAMESPACE_DEPARTMENT --clusterrole=microservices-kubernetes-namespace-reader --serviceaccount=$NAMESPACE_DEPARTMENT:default
kubectl create clusterrolebinding service-pod-reader-$NAMESPACE_EMPLOYEE --clusterrole=microservices-kubernetes-namespace-reader --serviceaccount=$NAMESPACE_EMPLOYEE:default
kubectl create clusterrolebinding service-pod-reader-$NAMESPACE_GATEWAY --clusterrole=microservices-kubernetes-namespace-reader --serviceaccount=$NAMESPACE_GATEWAY:default
kubectl create clusterrolebinding service-pod-reader-$NAMESPACE_ORGANIZATION --clusterrole=microservices-kubernetes-namespace-reader --serviceaccount=$NAMESPACE_ORGANIZATION:default
kubectl create clusterrolebinding service-pod-reader-$NAMESPACE_MONGO --clusterrole=microservices-kubernetes-namespace-reader --serviceaccount=$NAMESPACE_MONGO:default



