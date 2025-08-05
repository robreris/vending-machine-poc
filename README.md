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

You'll need to update the deployment specs in k8s.yaml with the repository URIs. For example:

```
...
    spec:
      containers:
      - name: backend
        image: <paste your repository URI here>
        ports:
        - containerPort: 5000
...
```

To configure the AWS Load Balancer Controller with TLS, you can set up a Route 53 Hosted Zone and request a certificate with AWS ACM for your domain name. Please reference these links for more information on how to do that:

* https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/CreatingHostedZone.html
* https://docs.aws.amazon.com/acm/latest/userguide/acm-public-certificates.html
* https://docs.aws.amazon.com/acm/latest/userguide/dns-validation.html

Once you have a Route 53 hosted zone and ACM certificate set up, [External DNS](https://artifacthub.io/packages/helm/bitnami/external-dns) can be used to update the former each time you create/destroy the Ingress objects. Be sure to update the Ingress object annotations in k8s.yaml with the ACM certificate ARN and and your hostname:

```
...
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}, {"HTTPS": 443}]'
    alb.ingress.kubernetes.io/certificate-arn: <paste your ACM certificate ARN here>
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    external-dns.alpha.kubernetes.io/hostname: <paste your DNS/hostname here; e.g. myapp.com>
spec:
  rules:
    - host: <paste your DNS/hostname here>
      http:
        paths:
...
```

**Note on certificates:** The hostname you choose must exactly match your certificate domain name, but you can use wildcard domains. Say you have a Route 53 hosted zone for myapps.com. You can request a certificate for *.myapps.com, and then for your hostname in k8s.yaml, you can specify any subdomain you like for the hostname (vm-test.myapps.com, myvm.myapps.com, etc.). 

After updating k8s.yaml, to go ahead and deploy the cluster, IAM roles, k8s service accounts, and install the External DNS and AWS Load Balancer contoller helm charts, run the create script:

```
./create_cluster.sh
```


