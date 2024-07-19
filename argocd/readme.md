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
**3. Add Helm Repository**
Add the ArgoCD Helm repository to your Helm configuration:
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```
**4. Install ArgoCD using Helm**
Install ArgoCD using the Helm chart and the provided values file:

```yaml
global:
  domain: argocd.hostname.com

configs:
  params:
    server.insecure: true

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

**5. Access ArgoCD**
You can now access the ArgoCD UI. To get the initial `admin` password:

```bash
kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d
```

Change the admin password using the UI and delete the `argocd-initial-admin-secret` secret.

```bash
kubectl delete secret argocd-initial-admin-secret -n argocd
```

## TBD: Section on Applications

In this section, you will learn how to:

Create ArgoCD applications.
Manage application life cycles.
Sync and rollback applications.