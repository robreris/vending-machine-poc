# =========================
# Makefile for EKS bootstrap
# =========================
SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

# -------- Config --------
AWS_ACCT           ?= 228122752878
AWS_DEFAULT_REGION ?= us-east-1
cluster_name       ?= vending-machine-poc
app_namespace      ?= vm-apps
elb_controller_namespace ?= aws-elb-controller-namespace
key_name           ?= fgt-kp
route53_domain     ?= robs-fortinet-apps.com

export AWS_DEFAULT_REGION

# -------- Help --------
.PHONY: help
help: ## Show targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | sed 's/:.*##/: /' | sort

# -------- Orchestration --------
.PHONY: up
up: create-cluster iam-oidc iam-roles extract-iam-roles configure-sa install-lb-controller install-externaldns ## Full bring-up

.PHONY: controllers
controllers: install-lb-controller install-externaldns ## Only install controllers

.PHONY: down
down: ## Delete the cluster (eksctl)
        for i in `helm list -n default -o json | jq -r .[].name`; do helm uninstall $i; done
	aws cloudformation delete-stack --stack-name eks-addon-roles
	eksctl delete cluster --name "$(cluster_name)" --region "$(AWS_DEFAULT_REGION)"

# -------- Cluster --------
.PHONY: create-cluster
create-cluster: ## Create the EKS cluster + namespaces
	eksctl create cluster -f arch/event-poc-cluster.yaml
	kubectl create namespace "$(app_namespace)" || true
	kubectl create namespace "$(elb_controller_namespace)" || true
	$(MAKE) get-cluster-info

# -------- Info --------
.PHONY: get-cluster-info
get-cluster-info: ## Resolve and print VPC/Subnets/Cluster SG, export as vars for this run
	CLUSTER_INFO="$$(eksctl get cluster --name "$(cluster_name)" --region "$(AWS_DEFAULT_REGION)" -o json)"
	VPC_ID="$$(echo "$$CLUSTER_INFO" | jq -r '.[0].ResourcesVpcConfig.VpcId')"
	SUBNET_IDS="$$(echo "$$CLUSTER_INFO" | jq -r '.[0].ResourcesVpcConfig.SubnetIds[]' | head -n 2)"
	SUBNET_ID_1="$$(echo "$$SUBNET_IDS" | sed -n '1p')"
	SUBNET_ID_2="$$(echo "$$SUBNET_IDS" | sed -n '2p')"
	SG_ID="$$(aws ec2 describe-instances \
	  --filters "Name=tag:eks:cluster-name,Values=$(cluster_name)" \
	  --query 'Reservations[*].Instances[*].SecurityGroups[*].GroupId' --output text | tr '\t' '\n' | sort -u)"
	echo "#### Cluster VPC Info ###"
	echo "VPC Id: $$VPC_ID"
	echo "Subnet ID 1: $$SUBNET_ID_1"
	echo "Subnet ID 2: $$SUBNET_ID_2"
	echo "Cluster Security Group: $$SG_ID"
	# Export into a file for later targets in this session
	echo "VPC_ID=$$VPC_ID"       > .cluster.env
	echo "SUBNET_ID_1=$$SUBNET_ID_1" >> .cluster.env
	echo "SUBNET_ID_2=$$SUBNET_ID_2" >> .cluster.env
	echo "SG_ID=$$SG_ID"             >> .cluster.env

# -------- IAM / OIDC --------
.PHONY: iam-oidc
iam-oidc: ## Associate OIDC
	eksctl utils associate-iam-oidc-provider --cluster "$(cluster_name)" --approve

.PHONY: get-oidc-id
get-oidc-id: ## Print OIDC ID
	OIDCId="$$(aws eks describe-cluster --name "$(cluster_name)" --query "cluster.identity.oidc.issuer" --output text | cut -d'/' -f5)"
	if [[ -z "$$OIDCId" ]]; then
	  echo "OIDC Id not found." && exit 1
	else
	  echo "OIDC ID: $$OIDCId"
	fi

.PHONY: iam-roles
iam-roles: ## Create IAM roles for addons via CloudFormation
	OIDCId="$$(aws eks describe-cluster --name "$(cluster_name)" --query "cluster.identity.oidc.issuer" --output text | cut -d'/' -f5)"
	aws cloudformation create-stack --stack-name eks-addon-roles \
	  --template-body file://./arch/sa-roles-cft.yml \
	  --parameters \
	    ParameterKey=ClusterName,ParameterValue=$(cluster_name) \
	    ParameterKey=OIDCId,ParameterValue=$$OIDCId \
	    ParameterKey=Namespace,ParameterValue=$(elb_controller_namespace) \
	  --capabilities CAPABILITY_NAMED_IAM \
	  --region "$(AWS_DEFAULT_REGION)" || true
	echo "⏳  Waiting for SA roles..."
	aws cloudformation wait stack-create-complete --stack-name eks-addon-roles || true

.PHONY: extract-iam-roles
extract-iam-roles: ## Wait for and capture addon role ARNs
	for role_key in ALBIngressRoleArn ExternalDNSRoute53RoleArn; do
	  for i in {1..30}; do
	    role_value="$$(aws cloudformation describe-stacks --stack-name eks-addon-roles --query "Stacks[0].Outputs[?OutputKey=='$$role_key'].OutputValue" --output text)"
	    if [[ -n "$$role_value" && "$$role_value" != "None" ]]; then
	      declare -g "$$role_key=$$role_value"
	      break
	    fi
	    echo "🔄 Waiting for $$role_key... ($$i/30)"
	    sleep 10
	  done
	done
	echo "Created roles:"
	echo "$$ALBIngressRoleArn"
	echo "$$ExternalDNSRoute53RoleArn"
	# Save for later targets
	{ echo "ALBIngressRoleArn=$$ALBIngressRoleArn"; echo "ExternalDNSRoute53RoleArn=$$ExternalDNSRoute53RoleArn"; } >> .cluster.env

# -------- Service Accounts (from arch/sa.yml) --------
.PHONY: configure-sa
configure-sa: ## Patch SA YAML with role ARNs and apply
	[[ -f .cluster.env ]] && source .cluster.env || true
	sed -i "/name: aws-alb-ingress-controller/,/eks.amazonaws.com\\/role-arn:/ s#^\\([[:space:]]*eks.amazonaws.com/role-arn:\\).*#\\1 $$ALBIngressRoleArn#" arch/sa.yml
	sed -i "/name: aws-alb-ingress-controller/,/namespace:/ s#^\\([[:space:]]*namespace:\\).*#\\1 $(elb_controller_namespace)#" arch/sa.yml
	sed -i "/name: externaldns-route53-sa/,/eks.amazonaws.com\\/role-arn:/ s#^\\([[:space:]]*eks.amazonaws.com/role-arn:\\).*#\\1 $$ExternalDNSRoute53RoleArn#" arch/sa.yml
	kubectl apply -f arch/sa.yml

# -------- AWS Load Balancer Controller --------
.PHONY: install-lb-controller
install-lb-controller: ## Install/upgrade AWS LB Controller (with CRD wait + retries)
	[[ -f .cluster.env ]] && source .cluster.env || true
	echo "Installing AWS load balancer controller helm chart..."
	# Ensure CRDs exist
	kubectl apply -f crds/crds.yaml
	required_crds=(ingressclassparams.elbv2.k8s.aws targetgroupbindings.elbv2.k8s.aws)
	for crd in "$${required_crds[@]}"; do
	  until kubectl get crd "$$crd" &>/dev/null; do
	    echo "Waiting for CRD $$crd..."
	    sleep 1
	  done
	done
	for crd in "$${required_crds[@]}"; do
	  kubectl wait --for=condition=Established "crd/$$crd" --timeout=120s
	done
	helm repo add eks https://aws.github.io/eks-charts || true
	helm repo update
	MAX_ATTEMPTS=8
	DELAY=5
	attempt=1
	while :; do
	  if helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
	      -n "$(elb_controller_namespace)" \
	      --set clusterName="$(cluster_name)" \
	      --set serviceAccount.create=false \
	      --set serviceAccount.name=aws-alb-ingress-controller \
	      --set region="$(AWS_DEFAULT_REGION)" \
	      --set vpcId="$${VPC_ID:-}" \
	      --set image.repository=602401143452.dkr.ecr.$(AWS_DEFAULT_REGION).amazonaws.com/amazon/aws-load-balancer-controller \
	      --wait --atomic --timeout 10m; then
	    echo "ALB controller install/upgrade succeeded."
	    break
	  fi
	  if [[ $$attempt -ge $$MAX_ATTEMPTS ]]; then
	    echo "[helm] failed after $$MAX_ATTEMPTS attempts."
	    exit 1
	  fi
	  echo "[helm] attempt $$attempt failed; sleeping $$DELAY s before retry..."
	  sleep "$$DELAY"
	  attempt=$$((attempt + 1))
	  DELAY=$$(( DELAY < 60 ? DELAY * 2 : 60 ))
	done
	kubectl wait deployment aws-load-balancer-controller -n "$(elb_controller_namespace)" --for=condition=Available=true --timeout=120s
	sleep 15

# -------- ExternalDNS --------
.PHONY: install-externaldns
install-externaldns: ## Install ExternalDNS (Bitnami)
	helm repo add bitnami https://charts.bitnami.com/bitnami || true
	helm repo update
	helm upgrade --install external-dns bitnami/external-dns \
	  --namespace kube-system \
	  --set provider=aws \
	  --set policy=upsert-only \
	  --set aws.zoneType=public \
	  --set domainFilters={$(route53_domain)} \
	  --set txtOwnerId=my-eks-cluster \
	  --set serviceAccount.create=false \
	  --set serviceAccount.name=externaldns-route53-sa
