# "[Sealed Secrets](https://github.com/bitnami-labs/sealed-secrets)" for Kubernetes


Problem: "I can manage all my K8s config in git, except Secrets."

Solution: Encrypt your Secret into a SealedSecret, which is safe to store - even inside a public repository. The SealedSecret can be decrypted only by the controller running in the target cluster and nobody else (not even the original author) is able to obtain the original Secret from the SealedSecret.

## Steps

### 1. Deploy sealed secrets controller

```bash
helm repo add sealed-secrets https://bitnami-labs.github.io/sealed-secrets
helm install sealed-secrets -n kube-system --set-string fullnameOverride=sealed-secrets-controller sealed-secrets/sealed-secrets
```
> The `kubeseal CLI` looks for the default controller named **sealed-secrets-controller** in the **kube-system** namespace.
> If you install the controller with these default values, you can use `kubeseal CLI` without needing to specify the namespace and the controller name.

### 2. Install the kubeseal CLI

```bash
KUBESEAL_VERSION='0.23.0' # Set this to, for example, KUBESEAL_VERSION='0.23.0'
curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION:?}/kubeseal-${KUBESEAL_VERSION:?}-linux-amd64.tar.gz"
tar -xvzf kubeseal-${KUBESEAL_VERSION:?}-linux-amd64.tar.gz kubeseal
sudo install -m 755 kubeseal /usr/local/bin/kubeseal
```
>where `KUBESEAL_VERSION` is the [version tag](https://github.com/bitnami-labs/sealed-secrets/tags) of the kubeseal release you want to use. For example: 0.23.0.

## usage
### 1. encoding k8s secret into sealed secret
To encode this Kubernetes Secret into a Sealed Secret, use the kubeseal CLI:
```bash
kubeseal --format yaml < secret.yaml > sealedsecret.yaml
```
### 2. decoding sealed secret
To decode a Sealed Secret back into a Kubernetes Secret, you can apply the Sealed Secret to your Kubernetes cluster. The Sealed Secrets controller will automatically decrypt it and create a Kubernetes Secret.
### 3. deleting sealed secret
Deleting the Sealed Secret will automatically delete the corresponding Kubernetes Secret that contains the decrypted sensitive data.
```bash
kubectl delete sealedsecrets <mysecret>
```
