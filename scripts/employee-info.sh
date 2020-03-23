#!/bin/bash

set -x

. ./set-env.sh

http $(minikube service employee --url -n $NAMESPACE_EMPLOYEE)/actuator/info