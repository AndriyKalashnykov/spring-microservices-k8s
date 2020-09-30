#!/bin/bash

set -x

. ./set-env.sh

# add employee
curl -X POST "$(minikube service employee --url -n $NAMESPACE_EMPLOYEE)/" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"age\": 25, \"departmentId\": 1, \"id\": \"1\", \"name\": \"Smith\", \"organizationId\": 1, \"position\": \"engineer\"}"
curl -X POST "$(minikube service employee --url -n $NAMESPACE_EMPLOYEE)/" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"age\": 45, \"departmentId\": 1, \"id\": \"2\", \"name\": \"Johns\", \"organizationId\": 1, \"position\": \"manager\"}"

# get employee
http $(minikube service employee --url -n $NAMESPACE_EMPLOYEE)/

# add department
curl -X POST "$(minikube service department --url -n $NAMESPACE_DEPARTMENT)/" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"employees\": [ { \"age\": 25, \"id\": 1, \"name\": \"Smith\", \"position\": \"engineer\" }, { \"age\": 45, \"id\": 2, \"name\": \"Johns\", \"position\": \"manager\" } ], \"id\": \"1\", \"name\": \"RD Dept.\", \"organizationId\": 1}"
curl -X POST "$(minikube service department --url -n $NAMESPACE_DEPARTMENT)/" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"employees\": [ { \"age\": 45, \"id\": 2, \"name\": \"Johns\", \"position\": \"manager\" } ], \"id\": \"1\", \"name\": \"RD Dept.\", \"organizationId\": 1}"

# get department
http $(minikube service department --url -n $NAMESPACE_DEPARTMENT)/


# add organization
curl -X POST "$(minikube service organization --url -n $NAMESPACE_ORGANIZATION)/" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"address\": \"Main Street\", \"departments\": [ { \"employees\": [ { \"age\": 25, \"id\": 1, \"name\": \"Smith\", \"position\": \"engineer\" } ], \"id\": 1, \"name\": \"Smith\" } ], \"employees\": [ { \"age\": 25, \"id\": 1, \"name\": \"Smith\", \"position\": \"engineer\" } ], \"id\": \"1\", \"name\": \"MegaCorp\"}"

# get organization
http $(minikube service organization --url -n $NAMESPACE_ORGANIZATION)/1/with-employees

# get via gatway:nodeport
#GATEWAY_NODEPORT=$(kubectl get -o jsonpath="{.spec.ports[0].nodePort}" services gateway -n $NAMESPACE_GATEWAY)
#http http://microservices-cluster.info:${GATEWAY_NODEPORT}/employee/

# via ingress
#http http://microservices-cluster.info/employee/
#APP_URL=http://localhost:8080/
#curl -X POST "$APP_URL" -H "accept: */*" -H "Content-Type: application/json" -d "{ \"age\": 25, \"departmentId\": 1, \"id\": \"1\", \"name\": \"Smith\", \"organizationId\": 1, \"position\": \"engineer\"}"
#curl -X GET "$APP_URL" -H "accept: */*" -H "Content-Type: application/json"