# ArgoCD Installation Guide

## Introduction

ArgoCD is a declarative, GitOps continuous delivery tool for Kubernetes. It automates the deployment of the desired application states in specified Kubernetes clusters. By using ArgoCD, you can:

- Manage your Kubernetes applications declaratively.
- Synchronize your applications automatically.
- Rollback to a previous state easily.
- Visualize your application's state and history.

## Steps to Install ArgoCD

**1. Create Namespace for ArgoCD**
First, create a namespace for ArgoCD in your Kubernetes cluster:
```bash
kubectl create namespace argocd
```
**2. Create and Apply the Sealed Secret**
Next, create a Sealed Secret for ArgoCD. Ensure the name of the secret is **`argocd-server-tls`** because ArgoCD looks for this specific secret:
```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  name: argocd-server-tls # do not change name
  namespace: argocd
spec:
  encryptedData:
    tls.crt: <sealed crt>
    tls.key: <sealed key>
  template:
    metadata:
      name: argocd-server-tls # do not change name
      namespace: argocd
    type: kubernetes.io/tls
```
Apply the Sealed Secret to your cluster:

```bash
kubectl apply -f path/to/your/sealed-secret.yaml
```

**3. Create and Apply the GitHub webhook Secret**
- **Create a GitHub Webhook:** Set up a webhook for your GitOps repository. Make sure to assign a webhook secret and set the `Content-Type` of the webhook to `application/json`.

- **Create a Sealed Secret:** Create a Kubernetes Sealed Secret containing the webhook secret value. Ensure that the Sealed Secret has the label `app.kubernetes.io/part-of: argocd`.

```yaml
apiVersion: bitnami.com/v1alpha1
kind: SealedSecret
metadata:
  creationTimestamp: null
  name: argocd-webhook-secret
  namespace: argocd
spec:
  encryptedData:
    webhook.github.secret: <sealed webhook secret>
  template:
    metadata:
      creationTimestamp: null
      labels:
        app.kubernetes.io/part-of: argocd
      name: argocd-webhook-secret
      namespace: argocd
    type: Opaque
```
- **Apply the Sealed Secret:** Deploy the Sealed Secret to your Kubernetes cluster.

```bash
kubectl apply -f path/to/your/sealed-secret.yaml
```

**4. Add Helm Repository**
Add the ArgoCD Helm repository to your Helm configuration:
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```
**5. Install ArgoCD using Helm**
Install ArgoCD using the Helm chart and the provided values file:

```yaml
global:
  domain: argocd.talrozen.com

configs:
  params:
    server.insecure: true
  secret:
    # Configuring ArgoCD to Reference the GitHub Webhook Secret
    # githubSecret: $<k8s_secret_name>:<a_key_in_that_k8s_secret>
    githubSecret: $argocd-webhook-secret:webhook.github.secret

server:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
      nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    tls: true

  ingressGrpc:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/backend-protocol: "GRPC"
    tls: true
```

```bash
helm install argocd argo/argo-cd -n argocd -f path/to/your/values.yaml
```

**6. Access ArgoCD**
You can now access the ArgoCD UI. To get the initial `admin` password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

Change the admin password using the UI and delete the `argocd-initial-admin-secret` secret.

```bash
kubectl delete secret argocd-initial-admin-secret -n argocd
```

## Applications

To add a new application to ArgoCD, you need to apply an Application Custom Resource Definition (CRD).

Here’s an example of how to configure a portfolio application using a GitOps repository with a Helm chart:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: portfolio-prod # The name of the application in ArgoCD.
  namespace: argocd
spec:
  # Specifies the Kubernetes cluster and namespace where the application will be deployed.
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: portfolio-prod
  # Defines the source repository and path of the Helm chart, along with the target branch or revision.
  source:
    repoURL: 'https://github.com/Exital/portfolioGitOps.git'
    path: 'portfolio-webapp'
    targetRevision: 'master'

    helm:
      valueFiles:
        - values-prod.yaml
  
  project: default
  # Configures automatic synchronization with options for pruning and self-healing.
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```