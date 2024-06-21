# Configuring TLS on Your Cluster

Transport Layer Security (TLS) is a protocol that ensures privacy and data integrity between two communicating applications. In a cluster environment, TLS plays a crucial role in securing data transmission between nodes, preventing eavesdropping, tampering, and message forgery.

## Prerequisites
Before configuring TLS on your cluster, ensure you have set up the following prerequisites:

- A domain registered with Cloudflare.
- Sealed Secrets installed.

## Steps

### 1. Get TLS certificate from your domain provider (cloudflare)
Cloudflare offers free TLS certificates to secure your website's traffic. If you have a domain and use Cloudflare's services, you can obtain a free TLS certificate and private key for your domain. 
Log in to your Cloudflare account, navigate to SSL/TLS, choose Origin Server, click on Create Certificate, leave the default value, set the validity period to 15 years, and save the certificate and private key in files tls.crt, tls.key.

### 2. encode into base64
Encode the certificate and private key values into Base64 format
```bash
base64 -w 0 tls.crt > tls.crt.b64
base64 -w 0 tls.key > tls.key.b64
```

### 3. create a tls secret file
Create a TLS secret file that will be converted into a sealed secret.
> file name cloudflare-tls.yml
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: <your-tls-secret-name> # cloudflare-tls
type: kubernetes.io/tls
data:
  tls.crt: <tls.crt-base64-encoded-1-line>
  tls.key: <tls.key-base64-encoded-1-line>
```

### 4. use kubeseal and apply
Use `kubeseal` to seal the secret and apply using `kubectl`.
```bash
kubeseal --format yaml < cloudflare-tls.yml > sealed-cloudflare-tls.yml
kubectl apply -f sealed-cloudflare-tls.yml
```
>**Caution: Sealed Secrets encryption encodes the namespace as well, preventing them from being transferred between namespaces.**

### 5. you may now use the TLS secret with ingress
Use the TLS secret with ingress to have secure connetion when hosting.

```yaml
expose:
  type: ingress
  tls:
    enabled: true
    secret:
      secretName: "cloudflare-tls"
```
> example from harbor-values.yml
