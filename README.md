# GDG Budapest demo: Deep dive into Kubernetes secrets

This repository contains demo code for a presentation I gave at the [GDG Budapest meetup](https://gdg.community.dev/events/details/google-gdg-cloud-budapest-presents-devops-with-docker-kubernetes-k8s-secret-management-on-google-cloud/) on 22nd September 2022 titled **"Deep dive into Kubernetes secrets"**,
featuring GKE, Workload Identity and Secret Manager.

You can find the slides [here](slides.pdf).

## Prerequisites

- Foundational knowledge about GCP, Workload Identities and Kubernetes
- Google Cloud account

Tools:

- gcloud
- kubectl
- [gke-gcloud-auth-plugin](https://cloud.google.com/kubernetes-engine/docs/how-to/cluster-access-for-kubectl#install_plugin)
- helm
- kustomize

## Preparations

Follow the instructions below if you want to start from scratch.
You can register an account for free and use free credit to follow this demo.

_Make sure to remain in the same shell during the demo. If you accidentally exit the shell, you can restore your variables with the following command:_

```shell
export PROJECT_ID=$(gcloud config get project)
export CLOUDSDK_COMPUTE_ZONE=europe-west3-a
```

### Set up a new project

Create a new Google Cloud project:

```shell
export PROJECT_ID=gdg-budapest-demo-$RANDOM
export CLOUDSDK_COMPUTE_ZONE=europe-west3-a

gcloud projects create $PROJECT_ID --name="GDG Budapest demo"

gcloud config set project $PROJECT_ID
```

Note: if you are working within an organization, you might need to add `--organization=ORG_ID` to the command above.

**Make sure to enable billing for the project you just created.**

Enable required services:

```shell
gcloud services enable container.googleapis.com
gcloud services enable iamcredentials.googleapis.com
gcloud services enable secretmanager.googleapis.com
```

### Set up a new Kubernetes cluster

Create a new Kubernetes cluster:

```shell
gcloud container clusters create --workload-pool=$PROJECT_ID.svc.id.goog gdg-budapest-demo
```

_Feel free to grab some coffee while the cluster is being deployed._

Once the cluster is deployed, grab the credentials:

```shell
gcloud container clusters get-credentials gdg-budapest-demo
```

Check your access to the cluster:

```shell
kubectl get nodes
kubectl get namespaces
```

### Create a secret in GCP Secret Manager

Last, but not least: create a secret:

```shell
echo -n "my super secret data" | gcloud secrets create my-secret --replication-policy="automatic" --data-file=-
```

Check that the secret was created:

```shell
gcloud secrets versions access latest --secret="my-secret"
```

## Set up [kube-secrets-init](https://github.com/doitintl/kube-secrets-init)

To install kube-secrets-init, add the following Helm repository first:

```shell
helm repo add skm https://charts.sagikazarmark.dev
helm repo update skm
```

Install kube-secrets-init:

```shell
helm install --namespace kube-secrets-init --create-namespace --values deploy/kube-secrets-init/values.yaml kube-secrets-init skm/kube-secrets-init
```

## Set up [External Secrets](https://external-secrets.io)

Create a new Kubernetes namespace:

```shell
kubectl create namespace external-secrets
```

Create a new Kubernetes service account:

```shell
kubectl create serviceaccount external-secrets --namespace external-secrets
```

Create a new IAM service account:

```shell
gcloud iam service-accounts create external-secrets
```

Assign the necessary roles to the IAM service account
(in our case, it will need access to the Secret Manager API):

```shell
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:external-secrets@$PROJECT_ID.iam.gserviceaccount.com" \
  --role "roles/secretmanager.secretAccessor"
```

**Note: in a production environment don't grant project-wide access to the Secret Manager,
rather manage access for each secret separately.**

Allow the Kubernetes service account to impersonate the IAM service account:

```shell
gcloud iam service-accounts add-iam-policy-binding external-secrets@$PROJECT_ID.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT_ID.svc.id.goog[external-secrets/external-secrets]"
```

Annotate the Kubernetes service account with the email address of the IAM service account:

```shell
kubectl annotate serviceaccount external-secrets --namespace external-secrets \
  iam.gke.io/gcp-service-account=external-secrets@$PROJECT_ID.iam.gserviceaccount.com
```

To install External Secrets, add the following Helm repository first:

```shell
helm repo add external-secrets https://charts.external-secrets.io
helm repo update external-secrets
```

Install External Secrets:

```shell
helm install --namespace external-secrets --values deploy/external-secrets/values.yaml external-secrets external-secrets/external-secrets
```

Create a Cluster Secret Store:

```shell
sed "s/PROJECT_ID/$PROJECT_ID/g" deploy/external-secrets/clustersecretstore.yaml | kubectl apply -f -
```

**Note: in a production environment you might want to consider namespace-scoped secret stores instead.**

## Demo: kube-secrets-init

Create a new IAM service account:

```shell
gcloud iam service-accounts create demo-kube-secrets-init
```

Assign the necessary roles to the IAM service account
(in our case, it will need access to the Secret Manager API):

```shell
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member "serviceAccount:demo-kube-secrets-init@$PROJECT_ID.iam.gserviceaccount.com" \
  --role "roles/secretmanager.secretAccessor"
```

**Note: in a production environment don't grant project-wide access to the Secret Manager,
rather manage access for each secret separately.**

Allow the Kubernetes service account to impersonate the IAM service account:

```shell
gcloud iam service-accounts add-iam-policy-binding demo-kube-secrets-init@$PROJECT_ID.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT_ID.svc.id.goog[demo-kube-secrets-init/demo]"
```

Deploy the demo to the cluster:

```shell
kustomize build demo/kube-secrets-init | sed "s/PROJECT_ID/$PROJECT_ID/g" | kubectl apply -f -
```

Take a look at the examples:

```shell
kubectl -n demo-kube-secrets-init port-forward deploy/demo-no-secret 8080
curl localhost:8080
# MY_SECRET=not secret at all

kubectl -n demo-kube-secrets-init port-forward deploy/demo-secret-env 8080
curl localhost:8080
# MY_SECRET=my super secret data

kubectl -n demo-kube-secrets-init port-forward deploy/demo-secret 8080
curl localhost:8080
# MY_SECRET=my super secret data
```

## Demo: External Secrets

Deploy the demo to the cluster:

```shell
kustomize build demo/external-secrets | sed "s/PROJECT_ID/$PROJECT_ID/g" | kubectl apply -f -
```

Take a look at the examples:

```shell
kubectl -n demo-external-secrets port-forward deploy/demo-no-secret 8080
curl localhost:8080
# MY_SECRET=not secret at all

kubectl -n demo-external-secrets port-forward deploy/demo-secret 8080
curl localhost:8080
# MY_SECRET=my super secret data
```

## Bonus: [Reloader](https://github.com/stakater/Reloader)

Although I didn't have time to demo Reloader, I mentioned it during the presentation,
so I thought I'd add it to the demo material.

First, install Reloader:

```shell
kustomize build deploy/reloader | kubectl apply -f -
```

Then, create a new secret in GCP Secret Manager:

```shell
echo -n "my super secret data before change" | gcloud secrets create my-other-secret --replication-policy="automatic" --data-file=-
```

Check that the secret was created:

```shell
gcloud secrets versions access latest --secret="my-other-secret"
```

Deploy the demo to the cluster:

```shell
kustomize build demo/reloader | sed "s/PROJECT_ID/$PROJECT_ID/g" | kubectl apply -f -
```

Take a look at the examples (before changing the secret):

```shell
kubectl -n demo-reloader port-forward deploy/demo-no-secret 8080
curl localhost:8080
# MY_SECRET=not secret at all

kubectl -n demo-reloader port-forward deploy/demo-secret 8080
curl localhost:8080
# MY_SECRET=my super secret data before change

kubectl -n demo-reloader port-forward deploy/demo-secret-reload 8080
curl localhost:8080
# MY_SECRET=my super secret data before change
```

Change the secret:

```shell
echo -n "my super secret data after change" | gcloud secrets versions add my-other-secret --data-file=-
```

Check that the secret was created:

```shell
gcloud secrets versions access latest --secret="my-other-secret"
```

Wait 10 seconds, then look at the secret examples again:

```shell
sleep 10

kubectl -n demo-reloader port-forward deploy/demo-secret 8080
curl localhost:8080
# MY_SECRET=my super secret data before change

kubectl -n demo-reloader port-forward deploy/demo-secret-reload 8080
curl localhost:8080
# MY_SECRET=my super secret data after change
```

Notice that the deployment was restarted after the secret change.

## Cleanup

Delete the secret:

```shell
gcloud secrets delete my-secret
gcloud secrets delete my-other-secret
```

Delete the cluster:

```shell
gcloud container clusters delete gdg-budapest-demo
```

Delete the project:

```shell
gcloud projects delete $PROJECT_ID
```

## References

- [GKE Workload Identity](https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity)
- [kube-secrets-init](https://github.com/doitintl/kube-secrets-init)
- [External Secrets](https://external-secrets.io)
- [Reloader](https://github.com/stakater/Reloader)
