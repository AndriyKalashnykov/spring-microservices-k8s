#!/bin/bash

#set -x

. ./set-env.sh

kubectl config set-context $CLUSTER1_NAME
kubectl config use-context $CLUSTER1_NAME

# this will only work if Employee Docker image build  from non-distroless image with layers copied over see example below:
kubectl get pod -n $NAMESPACE_EMPLOYEE -l 'app=employee' --no-headers | awk '{print $1}' | xargs -I {} echo "kubectl exec -it {} -n \"$NAMESPACE_EMPLOYEE\" -- /bin/bash"

# Changes to ./employee-service/Dockerfile

#FROM adoptopenjdk/openjdk${JDK_VERSION}
#COPY --from=build /application/dependencies/ ./
#COPY --from=build /application/snapshot-dependencies/ ./
#COPY --from=build /application/resources/ ./
#COPY --from=build /application/application/ ./


