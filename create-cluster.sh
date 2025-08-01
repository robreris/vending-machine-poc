#!/bin/bash
set -euo pipefail

#===================#
# Config Variables  #
#===================#
export AWS_ACCT="228122752878"
export AWS_DEFAULT_REGION=us-east-1

cluster_name="vending-machine-poc"
app_namespace="vm-apps"
elb_controller_namespace="aws-elb-controller-namespace"
key_name="fgt-kp"

#===================#
# Usage Check       #
#===================#
check_args() {
  if [ $# -eq 0 ] || [ $# -gt 1 ]; then
    echo "Zero or too many arguments supplied..."
    echo "Example: ./create-scripts/create-cluster.sh v1"
    exit 1
  fi
  echo "Launching $VERS setup...."
}

#===================#
# Cluster Setup     #
#===================#
create_cluster() {
  eksctl create cluster -f arch/event-poc-cluster.yaml
  kubectl create namespace $app_namespace
  kubectl create namespace $elb_controller_namespace
  get_cluster_info
}

#===================#
# Get Cluster Info  #
#===================#
get_cluster_info() {
  declare -g CLUSTER_INFO=$(eksctl get cluster --name "$cluster_name" --region "$AWS_DEFAULT_REGION" -o json)
  declare -g VPC_ID=$(echo "$CLUSTER_INFO" | jq -r '.[0].ResourcesVpcConfig.VpcId')
  declare -g SUBNET_IDS=$(echo "$CLUSTER_INFO" | jq -r '.[0].ResourcesVpcConfig.SubnetIds[]' | head -n 2)
  declare -g SUBNET_ID_1=$(echo "$SUBNET_IDS" | sed -n '1p')
  declare -g SUBNET_ID_2=$(echo "$SUBNET_IDS" | sed -n '2p')
  declare -g SG_ID=$(aws ec2 describe-instances --filters "Name=tag:eks:cluster-name,Values=$cluster_name" --query 'Reservations[*].Instances[*].SecurityGroups[*].GroupId' --output text | uniq)
  echo "#### Cluster VPC Info ###"
  echo "VPC Id: $VPC_ID"
  echo "Subnet ID 1: $SUBNET_ID_1"
  echo "Subnet ID 2: $SUBNET_ID_2"
  echo "Cluster Security Group: $SG_ID"
}


#===================#
# IAM/OIDC Setup    #
#===================#
setup_oidc_and_roles() {
  eksctl utils associate-iam-oidc-provider --cluster "$cluster_name" --approve
  get_oidc_id

  aws cloudformation create-stack --stack-name eks-addon-roles \
    --template-body file://./arch/sa-roles-cft.yml \
    --parameters \
      ParameterKey=ClusterName,ParameterValue=$cluster_name \
      ParameterKey=OIDCId,ParameterValue=$OIDCId \
      ParameterKey=Namespace,ParameterValue=$elb_controller_namespace \
    --capabilities CAPABILITY_NAMED_IAM \
    --region $AWS_DEFAULT_REGION

  echo "⏳  Waiting for SA roles..."
  aws cloudformation wait stack-create-complete --stack-name eks-addon-roles
}


#=====================#
# Retrieve OIDC ID    #
#=====================#
get_oidc_id() {
  declare -g OIDCId=$(aws eks describe-cluster --name $cluster_name --query "cluster.identity.oidc.issuer" --output text | cut -d'/' -f5)
  if [[ "$OIDCId" == "" ]]; then
    echo "OIDC Id not found."
  else 
    echo "OIDC ID: $OIDCId"
  fi
}

#===========================#
# Extract IAM Role Outputs #
#===========================#
extract_iam_roles() {
  for role_key in ALBIngressRoleArn; do
    for i in {1..30}; do
      role_value=$(aws cloudformation describe-stacks --stack-name eks-addon-roles --query "Stacks[0].Outputs[?OutputKey=='$role_key'].OutputValue" --output text)
      if [[ -n "$role_value" ]]; then
        declare -g "$role_key"="$role_value"
        break
      fi
      echo "🔄 Waiting for $role_value... ($i/30)"
      sleep 10
    done
  done

  echo "Created roles:"
  echo $ALBIngressRoleArn
}

#============================#
# Update and Apply SA YAML  #
#============================#
configure_service_accounts() {

  sed -i "/name: aws-alb-ingress-controller/,/eks.amazonaws.com\/role-arn:/ s#^\([[:space:]]*eks.amazonaws.com/role-arn:\).*#\1 $ALBIngressRoleArn#" arch/sa.yml
  sed -i "/name: aws-alb-ingress-controller/,/namespace:/ s#^\([[:space:]]*namespace:\).*#\1 $elb_controller_namespace#" arch/sa.yml

  kubectl create -f arch/sa.yml
}

#=============================#
# Load Balancer Controller   #
#=============================#
install_lb_controller() {
  echo "Installing AWS load balancer controller helm chart..."

  required_crds=(
    ingressclassparams.elbv2.k8s.aws
    targetgroupbindings.elbv2.k8s.aws
  )

 # echo "Deploying and waiting for aws lb controller CRDs to be ready..."
 # kubectl create -k "github.com/aws/eks-charts/stable/aws-load-balancer-controller//crds?ref=master"
 # for crd in "${required_crds[@]}"; do
 #   until kubectl get crd "$crd" &> /dev/null; do
 #     echo "Waiting for CRD $crd..."
 #     sleep 1
 #   done
 # done

 # sleep 10

  helm repo add eks https://aws.github.io/eks-charts

  helm install aws-load-balancer-controller eks/aws-load-balancer-controller \
    -n $elb_controller_namespace \
    --set clusterName=$cluster_name \
    --set serviceAccount.create=false \
    --set serviceAccount.name=aws-alb-ingress-controller \
    --set region=$AWS_DEFAULT_REGION \
    --set setvpcId=$VPC_ID \
    --set image.repository=602401143452.dkr.ecr.us-east-1.amazonaws.com/amazon/aws-load-balancer-controller

  kubectl wait deployment aws-load-balancer-controller -n $elb_controller_namespace --for=condition=Available=true --timeout=120s
  sleep 15
}

#=====================#
# Execution Control   #
#=====================#
main() {

  # set up cluster
  #check_args "$@"
  #create_cluster
  get_cluster_info

  # iam/service accounts
  #setup_oidc_and_roles
  #get_oidc_id
  #extract_iam_roles
  #configure_service_accounts
 
  # alb ingress controller
  install_lb_controller

}

main "$@"
