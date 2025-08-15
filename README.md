## Account Vending Machine POC/MVP Set-Up in EKS

### What You'll Need

* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* [eksctl](https://eksctl.io/installation/)
* [helm](https://helm.sh/docs/intro/install/)

### Setup

To get started, configure your command line environment and permissions:

```
aws configure sso
```

Then, navigate to each app directory, build the images, and push to your repository.

```
cd apps/frontend
docker build -t frontend-microservice .

cd apps/backend
docker build -t backend-microservice .
```

The Makefile contains steps to deploy the AWS Load Balancer Controller and External DNS into your cluster.

To configure the AWS Load Balancer Controller with TLS, you can set up a Route 53 Hosted Zone and request a certificate with AWS ACM for your domain name. Please reference these links for more information on how to do that:

* https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingHostedZone.html
* https://docs.aws.amazon.com/acm/latest/userguide/acm-public-certificates.html
* https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html

Once you have a Route 53 hosted zone and ACM certificate set up, [External DNS](https://artifacthub.io/packages/helm/bitnami/external-dns) can be used to update the former each time you create/destroy the Ingress objects.

**Note on certificates:** The hostname you choose must exactly match your certificate domain name, but you can use wildcard domains. Say you have a Route 53 hosted zone for myapps.com. You can request a certificate for *.myapps.com, and then for your hostname in k8s.yaml, you can specify any subdomain you like for the hostname (vm-test.myapps.com, myvm.myapps.com, etc.). 

Update the values.yaml files in `apps/backend` and `apps/frontend` with the requisite details including port, hostname, certificate ARN information. Then update the values as needed/desired in the `Makefile` config section, and deploy:

```
make up
```

To launch frontend and backend apps:

```
helm upgrade --install frontend ./apps/charts/shared -f apps/frontend/values.yaml -n default
helm upgrade --install greeting-backend ./apps/charts/shared -f apps/greeting-backend/values.yaml -n default
```

### Terraform notes

`arch/registry/main.tf`

Declaratively manages all ECR repositories for the environment.

- Discovers services by scanning `apps/*/values.yaml`.
- Extracts the ECR repo name.
- Calls `modules/microservice-ecr` once per repo.
- Exposes:
  - `repository_urls` (map: repo_name → full ECR URL)
  - `repo_to_service` (map: repo_name → service folder)

`arch/registry/backend.tf`

Manages backend in S3 and DynamoDB (for locking).

`modules/microservice-ecr/`

Creates one ECR repository (for an application).

`apps/<service>/terraform/`

Manages app-owned resources if needed. main.tf is required (along with values.yaml).

### Helm notes

`apps/charts/shared/templates`

Templates for deployments, services, and ingress. 

`apps/<service>/values.yaml`

Variables for an application that helm uses in chart construction. 

`apps/charts/shared/values.yaml`

Variables shared across applications.

### To add a new application

The service folder under apps/ will need to contain a few things:
* An `app` folder containing all application code including the Dockerfile and everything needed to containerize it
* A `values.yaml` file. The ECR repository name will be set to the `name` defined in values.yaml. Also specify any port settings you wish to change from the defaults.
* A `terraform` folder containing the terraform template for a new ECR repository.

#### Updating the frontend
