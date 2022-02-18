#!/bin/bash

set -x

. ./set-env.sh

#xdg-open $(minikube service gateway --url -n=$NAMESPACE_GATEWAY)/swagger-ui.html

kubectl get pod -n $NAMESPACE_GATEWAY -l 'app=gateway' --no-headers | awk '{print $1}' | xargs -I {} sh -c "echo {}; xdg-open $(minikube service gateway --url -n gateway)/swagger-ui.html"