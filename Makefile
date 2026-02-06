# =========================
# Makefile for EKS bootstrap
# =========================
SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c

ifneq (,$(wildcard .cluster.env))
include .cluster.env
endif

FORTIFLEX_TABLE := $(strip $(or $(TABLE),$(PRODUCTS_TABLE_NAME)))
FORTIFLEX_ROLE  := $(strip $(or $(ROLE),$(DYNAMODB_READER_ROLE_ARN)))

# -------- Config --------
AWS_ACCT           ?= 228122752878
AWS_DEFAULT_REGION ?= us-east-1
AWS_PROFILE        ?= our-eks
ECR_REGISTRY       ?= $(AWS_ACCT).dkr.ecr.$(AWS_DEFAULT_REGION).amazonaws.com
cluster_name       ?= vending-machine-poc
app_namespace      ?= vm-apps
elb_controller_namespace ?= aws-elb-controller-namespace
key_name           ?= fgt-kp
route53_domain     ?= fortinetcloudcse.com
Route53ZoneID      ?= Z03896823RCWOLV8SE6UO
SHARED_VALUES_FILE ?= apps/charts/shared/values.yaml
GITHUB_WORKFLOW    ?= build-deploy.yml
GITHUB_REF         ?= main

export AWS_DEFAULT_REGION
export AWS_PROFILE

# -------- Help --------
.PHONY: help
help: ## Show targets
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | sed 's/:.*##/: /' | sort

# -------- Orchestration --------
.PHONY: up
up: create-cluster iam-oidc iam-roles extract-iam-roles configure-sa install-lb-controller install-externaldns provision-dynamodb ## Full bring-up

.PHONY: controllers
controllers: install-lb-controller install-externaldns ## Only install controllers

.PHONY: down
down: ## Delete the cluster (eksctl)
	$(MAKE) uninstall-app-helm-charts || true
	$(MAKE) destroy-dynamodb || true
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
            ParameterKey=Route53ZoneID,ParameterValue=$$Route53ZoneID \
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
	helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/ || true
	helm repo update
	helm upgrade --install external-dns external-dns/external-dns \
	  --namespace kube-system \
	  --set provider.name=aws \
	  --set policy=upsert-only \
	  --set domainFilters[0]=$(route53_domain) \
	  --set txtOwnerId=my-eks-cluster \
	  --set serviceAccount.create=false \
	  --set serviceAccount.name=externaldns-route53-sa \
	  --set image.repository=registry.k8s.io/external-dns/external-dns \
	  --set image.tag=v0.17.0 \
	  --set sources='{ingress}' \
	  --set extraArgs[0]=--aws-zone-type=public

.PHONY: provision-dynamodb
provision-dynamodb: ## Provision shared products DynamoDB table and IAM role
	terraform -chdir=arch/dynamodb init
	terraform -chdir=arch/dynamodb apply -auto-approve -var "cluster_name=$(cluster_name)"
	DYNAMODB_OUTPUTS="$$(terraform -chdir=arch/dynamodb output -json)"
	PRODUCTS_TABLE_NAME="$$(echo "$$DYNAMODB_OUTPUTS" | jq -r '.products_table_name.value')"
	DYNAMODB_READER_ROLE_ARN="$$(echo "$$DYNAMODB_OUTPUTS" | jq -r '.dynamodb_reader_role_arn.value')"
	if [[ -z "$$PRODUCTS_TABLE_NAME" || "$$PRODUCTS_TABLE_NAME" == "null" ]]; then \
	  echo "Failed to capture products_table_name output" >&2; exit 1; \
	fi
	if [[ -z "$$DYNAMODB_READER_ROLE_ARN" || "$$DYNAMODB_READER_ROLE_ARN" == "null" ]]; then \
	  echo "Failed to capture dynamodb_reader_role_arn output" >&2; exit 1; \
	fi
	touch .cluster.env
	sed -i '/^PRODUCTS_TABLE_NAME=/d' .cluster.env || true
	sed -i '/^DYNAMODB_READER_ROLE_ARN=/d' .cluster.env || true
	{ echo "PRODUCTS_TABLE_NAME=$$PRODUCTS_TABLE_NAME"; echo "DYNAMODB_READER_ROLE_ARN=$$DYNAMODB_READER_ROLE_ARN"; } >> .cluster.env

.PHONY: destroy-dynamodb
destroy-dynamodb: ## Destroy shared products DynamoDB table and IAM role
	@if [ ! -d arch/dynamodb ]; then \
	  echo "No arch/dynamodb directory found; skipping"; \
	else \
	  terraform -chdir=arch/dynamodb init; \
	  terraform -chdir=arch/dynamodb destroy -auto-approve -var "cluster_name=$(cluster_name)"; \
	fi

# -------- Helm charts --------
.PHONY: sync-shared-ecr-registry
sync-shared-ecr-registry: ## Update shared chart ECRregistry in-place from Makefile config
	@if grep -Eq '^[[:space:]]*ECRregistry:' "$(SHARED_VALUES_FILE)"; then \
	  sed -i -E "s#^([[:space:]]*ECRregistry:[[:space:]]*).*\$$#\1$(ECR_REGISTRY)#" "$(SHARED_VALUES_FILE)"; \
	else \
	  printf '\nECRregistry: %s\n' "$(ECR_REGISTRY)" >> "$(SHARED_VALUES_FILE)"; \
	fi
	@echo "Set ECRregistry in $(SHARED_VALUES_FILE) to $(ECR_REGISTRY)"

.PHONY: deploy-poc-helm-charts
deploy-app-helm-charts: sync-shared-ecr-registry
	helm upgrade --install frontend ./apps/charts/shared -f apps/vm-poc-frontend/values.yaml
	helm upgrade --install backend-greeting ./apps/charts/shared -f apps/vm-poc-backend-greeting/values.yaml
	helm upgrade --install backend-math ./apps/charts/shared -f apps/vm-poc-backend-math/values.yaml || true

.PHONY: deploy-fortiflex-marketplace
deploy-fortiflex-marketplace: sync-shared-ecr-registry
	@echo "Deploying FortiFlex Marketplace frontend and backend to default namespace..."
	helm upgrade --install vm-poc-frontend-fortiflex-marketplace ./apps/charts/shared \
	  -f apps/vm-poc-frontend-fortiflex-marketplace/values.yaml \
	  -n default
	helm upgrade --install vm-poc-backend-fortiflex-marketplace ./apps/charts/shared \
	  -f apps/vm-poc-backend-fortiflex-marketplace/values.yaml \
	  -n default  

.PHONY: deploy-fortiflex-poc
deploy-fortiflex-poc: sync-shared-ecr-registry
	helm upgrade --install frontend-fortiflex ./apps/charts/shared -f apps/vm-poc-frontend-fortiflex/values.yaml -n default
	if [ -z "$(FORTIFLEX_TABLE)" ] || [ -z "$(FORTIFLEX_ROLE)" ]; then \
	  echo "Missing table/role. Provide via make variables (e.g. 'make deploy-fortiflex-poc TABLE=... ROLE=...') or run 'make provision-dynamodb' first."; \
	  exit 1; \
	fi
	helm upgrade --install backend-fortiflex ./apps/charts/shared \
	  -f apps/vm-poc-backend-fortiflex/values.yaml \
	  -n default \
	  --set-string env.PRODUCTS_TABLE_NAME="$(FORTIFLEX_TABLE)" \
	  --set-string serviceAccount.annotations."eks\.amazonaws\.com/role-arn"="$(FORTIFLEX_ROLE)" \
	  --set-string env.AWS_REGION="$(AWS_DEFAULT_REGION)"

.PHONY: uninstall-app-helm-charts
uninstall-app-helm-charts:
	helm uninstall -n default $$(helm ls --short -n default)

.PHONY: kickoff-build-deploy-workflow
kickoff-build-deploy-workflow: sync-shared-ecr-registry
	gh workflow run "$(GITHUB_WORKFLOW)" --ref "$(GITHUB_REF)" -f ref="$(GITHUB_REF)"
