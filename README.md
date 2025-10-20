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

Update the configuration block at the top of the `Makefile` if you need to override the default AWS account, Route 53 domain, or key pair. Then bring the cluster online and install the controllers:

```
make up
```

This target creates the EKS cluster, provisions the IAM roles, deploys the AWS Load Balancer Controller, and installs ExternalDNS. You can rerun individual targets (for example `make install-externaldns`) if you need to reconcile specific components.

To configure the AWS Load Balancer Controller with TLS, you can set up a Route 53 Hosted Zone and request a certificate with AWS ACM for your domain name. Please reference these links for more information on how to do that:

* https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingHostedZone.html
* https://docs.aws.amazon.com/acm/latest/userguide/acm-public-certificates.html
* https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html

Once you have a Route 53 hosted zone and ACM certificate set up, [External DNS](https://artifacthub.io/packages/helm/bitnami/external-dns) can be used to update the former each time you create/destroy the Ingress objects.

**Note on certificates:** The hostname you choose must exactly match your certificate domain name, but you can use wildcard domains. Say you have a Route 53 hosted zone for myapps.com. You can request a certificate for *.myapps.com, and then for your hostname in k8s.yaml, you can specify any subdomain you like for the hostname (vm-test.myapps.com, myvm.myapps.com, etc.). 

Update the relevant `apps/vm-poc-*/values.yaml` files with any hostname, certificate ARN, or scaling changes you require. Sample deployments for the reference applications are available through the shared chart:

```
make deploy-app-helm-charts
```

If you need to iterate on an image locally, the Dockerfiles and source live under each service’s `app/` directory (for example `apps/vm-poc-frontend/app`). Build and push the image using the ECR repository URL exposed by Terraform or emitted by the GitHub workflow.

### CI/CD workflow

The `build-deploy` GitHub Actions workflow automatically:

- Runs `arch/registry` Terraform to discover `apps/*/values.yaml` files and create any missing ECR repositories.
- Builds and pushes each service image to its matching repository.
- Can be triggered on `main`, via pull requests, or manually with `workflow_dispatch` (specify the branch/ref when launching a manual run).

Because repositories are created on demand, adding a correctly structured service folder under `apps/` is enough for the workflow to reconcile the infrastructure and publish the image.

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

Optional folder for service-owned infrastructure. The shared Terraform in `arch/registry` already provisions the ECR repositories, so create additional modules here only when the service needs extra AWS resources.

### Helm notes

`apps/charts/shared/templates`

Templates for deployments, services, and ingress. 

`apps/<service>/values.yaml`

Variables for an application that helm uses in chart construction. 

`apps/charts/shared/values.yaml`

Variables shared across applications.

### Adding a new microservice

1. Create a new folder under `apps/` (for example `apps/vm-poc-backend-foo`).
2. Add an `app/` subfolder with your application code and Dockerfile. The Dockerfile will be used both locally and by the GitHub workflow during image builds.
3. Create a `values.yaml` file that, at minimum, defines a unique `name` (this becomes the ECR repository name and the Kubernetes release name), container port, and service settings. Use the existing services as references for environment variables that wire calls to other services.
4. (Optional) Add a `terraform/` subfolder only if the service owns additional AWS resources beyond its ECR repository.

The CI workflow will automatically detect the new `values.yaml`, provision the repository, and push images on the next run. Within Kubernetes, services communicate over DNS using the Helm release name (for example `http://vm-poc-backend-greeting:5000`). Configure environment variables or application settings in `values.yaml` so your new service can call its dependencies in the same way the sample frontend points at the backend services.

After the workflow publishes the image, deploy the service with the shared chart:

```
helm upgrade --install <service-name> ./apps/charts/shared -f apps/<service-name>/values.yaml -n <namespace>
```

Replace `<service-name>` with the folder you created and choose a namespace (`vm-apps` by default). Add or update Ingress configuration in `values.yaml` if the service needs external exposure; ExternalDNS will reconcile the DNS records when the controllers are installed.

#### Testing with Docker Compose

The root `compose.yaml` launches the Fortiflex reference services so you can exercise the stack locally:

```bash
docker compose up --build
```

To trial a brand-new microservice before wiring it into Terraform, Helm, or the CI workflow:

1. Scaffold the service under `apps/<service-name>/app` with a `Dockerfile`. The compose file builds images directly from these folders, so no registry push is needed.
2. Create a local override file (for example `compose.<service-name>.yaml`) that defines your service and any dependencies. Keep this file out of version control by storing it outside the repo or adding it to `.git/info/exclude`.
   
   ```yaml
   services:
     vm-poc-backend-foo:
       build:
         context: ./apps/vm-poc-backend-foo/app
       image: vm-poc-backend-foo:local
       environment:
         # Example: point at another local service
         FORTIFLEX_BACKEND_URL: http://vm-poc-backend-fortiflex:5000
       ports:
         - "5001:5000"
       depends_on:
         - vm-poc-backend-fortiflex
   ```

3. Start Compose with both files so your local definition is layered on top of the baseline stack:

   ```bash
   docker compose -f compose.yaml -f compose.vm-poc-backend-foo.yaml up --build vm-poc-backend-foo
   ```

   Omit the service name at the end if you also want the reference services running (`docker compose -f compose.yaml -f <override>.yaml up --build`).

4. Iterate on the image locally: `docker compose build vm-poc-backend-foo` rebuilds just your service, and `docker compose down` tears everything down when you are finished.
