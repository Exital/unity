## Enabling Master Node to Schedule Pods

To allow the master node to schedule pods, you can remove the taint that prevents it from doing so:

```bash
kubectl taint nodes <master-node-name> node-role.kubernetes.io/control-plane:NoSchedule-
```
> Replace <master-node-name> with the name of your master node.

This command removes the taint `node-role.kubernetes.io/control-plane` from the master node, enabling it to schedule pods.

## Reverting to Original State (Without Pods)

If you want to revert the master node to its original state (without scheduling pods), you can add the taint back:

```bash
kubectl taint nodes <master-node-name> node-role.kubernetes.io/control-plane=NoSchedule:NoSchedule
```
This command adds the `NoSchedule` taint back to the master node, preventing it from scheduling pods.

## Evicting Pods from Master Node

If you need to remove all running pods from the master node, you can use the kubectl drain command:
```bash
kubectl drain <master-node-name> --ignore-daemonsets
```
This command gracefully evicts all pods from the specified node, ensuring a smooth transition.
