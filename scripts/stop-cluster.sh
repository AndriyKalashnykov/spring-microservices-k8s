#!/bin/bash

set -e
set -x

. ./set-env.sh

minikube stop -p $CLUSTER1_NAME
