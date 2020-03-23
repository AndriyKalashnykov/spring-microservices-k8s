#!/bin/bash

set -x

. ./set-env.sh

. ./delete-app.sh

. ./delete-db.sh

#eval $(minikube docker-env)
#docker rmi $(docker images --format '{{.Repository}}:{{.Tag}}' | grep 'vmware/department:1.1')
#docker rmi $(docker images --format '{{.Repository}}:{{.Tag}}' | grep 'vmware/employee:1.1')
#docker rmi $(docker images --format '{{.Repository}}:{{.Tag}}' | grep 'vmware/gateway:1.1')
#docker rmi $(docker images --format '{{.Repository}}:{{.Tag}}' | grep 'vmware/organization:1.1')