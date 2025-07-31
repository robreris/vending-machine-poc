#!/bin/bash

export AWS_DEFAULT_REGION=us-east-1
app_namespace=vending-machine-apps
cluster_name=vending-machine-poc
#cluster_name=$(eksctl get cluster -o json | jq -r ".[0].Name")

kubectl delete -f k8s.yml

aws cloudformation delete-stack --stack-name eks-addon-roles

eksctl delete cluster $cluster_name
