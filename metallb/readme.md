
# MetalLB

MetalLB is a load-balancer implementation for bare metal Kubernetes clusters, using standard routing protocols. It allows for the allocation of external IP addresses for services in a bare metal environment, where cloud-based load-balancing solutions are not available.

For comprehensive documentation, visit [MetalLB Documentation](https://metallb.universe.tf).

## Installation Steps

### 1. Apply MetalLB YAML
Apply the MetalLB manifest, which includes its own namespace `metallb-system`:

```bash
kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.14.5/config/manifests/metallb-native.yaml
```


### 2. Apply Custom Resource YAMLs

Apply both the  `metallb-pool`  and  `l2advertisement`  custom resource manifests. Ensure to modify the values according to your environment.

For the  `metallb-pool`, make sure the IP range is within your local network and is not already taken.

```yml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: metallb-pool
  namespace: metallb-system
spec:
  addresses:
  - 192.168.0.200-192.168.0.210
```
> Ensure to replace the IP addresses and other values to match your network configuration.

Example configuration for `l2advertisement`:
```yml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: unity-l2
  namespace: metallb-system
spec:
  ipAddressPools:
  - metallb-pool
```
> Ensure to replace the name and ip address pools values to match your custom resource.


## Additional Resources
-   [MetalLB GitHub Repository](https://github.com/metallb/metallb)
