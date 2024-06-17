# [Harbor](https://github.com/goharbor/harbor-helm) Image registry

Harbor is an open-source container image registry that secures images with role-based access control, scans images for vulnerabilities, and signs images as trusted.

## Prerequisites

Before installing Harbor, you need to set up the following prerequisites:

- TLS Secret: Configure a TLS sealed secret in your Kubernetes cluster.
- NFS provisioner: To ensure data persistence in Harbor, you need a persistent volume provisioner.

## Steps

### 1. create admin password sealed secret

1. base64 encode your password

```bash
echo -n 'YourStrongPassword' | base64
```

2. create your k8s secret file

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: harbor-admin-secret
  namespace: harbor
type: Opaque
data:
  HARBOR_ADMIN_PASSWORD: <base64-encoded-password>
```
3. use kubeseal to create sealed secret

```bash
kubeseal --format yaml < harbor-admin-password-secret.yml > sealed-harbor-admin-password-secret.yml
```
4. apply the sealed secret
```bash
kubectl apply -f sealed-harbor-admin-password-secret.yml
```

### 2. install harbor using helm
Add helm repository
```bash
helm repo add harbor https://helm.goharbor.io
```

Install using harbor-values.yml
```yaml
expose:
  type: ingress
  tls:
    enabled: true
    secret:
      secretName: "<your-tls-secret-name>"
  ingress:
    hosts:
      core: <your-host>
    controller: nginx-ingress-controller
    className: "nginx"
    annotations:
      nginx.org/client-max-body-size: "0m"
externalURL: https://<your-host>
persistence:
  enabled: true
  persistentVolumeClaim:
    registry:
      storageClass: "<your-storage-class>"
      subPath: "harbor"
      size: 100Gi
    jobservice:
      jobLog:
        storageClass: "<your-storage-class>"
        subPath: "harbor"
        size: 5Gi
    database:
      storageClass: "<your-storage-class>"
      subPath: "harbor"
      size: 5Gi
    redis:
      storageClass: "<your-storage-class>"
      subPath: "harbor"
      size: 5Gi
    trivy:
      storageClass: "<your-storage-class>"
      subPath: "harbor"
      size: 5Gi
existingSecretAdminPassword: <your-admin-secret-name>
existingSecretAdminPasswordKey: <your-admin-secret-password-key-in-the-file> # in that example: HARBOR_ADMIN_PASSWORD
```
