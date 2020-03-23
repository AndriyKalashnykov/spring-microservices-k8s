#!/bin/bash

set -x

. ./set-env.sh

minikube profile $CLUSTER1_NAME
minikube ip