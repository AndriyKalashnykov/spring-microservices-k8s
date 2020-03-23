#!/bin/bash

set -e
set -x

. ./set-env.sh

cd ..

minikube profile $CLUSTER1_NAME

# make Kubernetes reusing Docker daemon
# https://kubernetes.io/docs/setup/minikube/#reusing-the-docker-daemon
eval $(minikube docker-env)
docker images

mvn clean

cd department-service
mvn clean package install
docker build -t vmware/department:1.1 .
cd ..

cd gateway-service
mvn clean package install
docker build -t vmware/gateway:1.1 .
cd ..

cd organization-service
mvn clean package install
docker build -t vmware/organization:1.1 .
cd ..


cd employee-service
mvn clean package install
docker build -t vmware/employee:1.1 .
cd ..

#minikube profile $CLUSTER2_NAME
#eval $(minikube docker-env)
#docker images

#mvn clean
docker images

cd scripts

# minikube delete --all