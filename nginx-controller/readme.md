# NGINX Ingress Controller

NGINX Ingress Controller is a popular Kubernetes Ingress controller that uses NGINX as a reverse proxy and load balancer. It manages incoming traffic to your Kubernetes applications, providing features like SSL termination, path-based routing, and more.

For detailed information and documentation, visit the [NGINX Ingress Controller Documentation](https://docs.nginx.com/nginx-ingress-controller/).

## Installation Steps

### 1. Create NGINX Ingress Namespace
Create a dedicated namespace for NGINX Ingress Controller:

```bash
kubectl create namespace nginx-ingress
```

### 2. Pull NGINX Controller Helm Chart
Pull the NGINX Ingress Controller Helm chart from the NGINX Helm repository:

```bash
helm pull oci://ghcr.io/nginxinc/charts/nginx-ingress --untar --version 1.2.2
```
> Ensure to replace 1.2.2 with the desired version of the NGINX Ingress Controller.

### 3. Install Custom Resource Definitions (CRDs)
Navigate to the extracted chart directory and install the Custom Resource Definitions (CRDs) required for the NGINX Ingress Controller:

```bash
cd nginx-ingress
kubectl apply -f crds
```

### 4. Install NGINX Ingress Controller
Install the NGINX Ingress Controller using Helm, specifying the chart directory and version:

```bash
helm install nginx-ingress oci://ghcr.io/nginxinc/charts/nginx-ingress --version 1.2.2 --namespace nginx-ingress --set controller.enableTLSPassthrough=true
```
> Ensure to replace 1.2.2 with the desired version of the NGINX Ingress Controller.

## Additional Resources
- [NGINX Ingress Controller GitHub Repository](https://github.com/nginxinc/kubernetes-ingress)
