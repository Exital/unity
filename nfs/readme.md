# NFS Setup Guide

This guide will help you set up Network File System (NFS) between multiple Linux servers, sharing a disk from one of the servers.

## Prerequisites

-   At least two Linux servers.
-   Administrative (root) access on all servers.
-   A disk on one of the servers to be shared.

## Steps

### 1. Install NFS Server

On the server that will share the disk (let's call it the NFS server):
```bash
sudo apt update
sudo apt install nfs-kernel-server
```
### 2. Configure the Shared Directory

Create the directory you want to share at `/nfs`:

```bash
sudo mkdir -p /nfs
```

Set appropriate permissions for the directory:

```bash
sudo chown nobody:nogroup /nfs
sudo chmod 755 /nfs
```
### 3. Export the Shared Directory

Edit the `/etc/exports` file to configure the shared directory:

```bash
sudo nano /etc/exports` 
```

Add the following line to share the directory with your client servers (replace `client_ip` with the actual IP addresses of your client servers):

```bash
/nfs client_ip_1(rw,sync,no_subtree_check) client_ip_2(rw,sync,no_subtree_check)
```

Save and close the file.

### 4. Apply Export Configuration

Run the following command to apply the changes:

```bash
sudo exportfs -a
```

### 5. Start the NFS Server

Ensure the NFS service is started and enabled to start on boot:

```bash
sudo systemctl start nfs-kernel-server
sudo systemctl enable nfs-kernel-server` 
```

### 6. Configure NFS Clients

On each client server that will access the NFS share:

1.  Install NFS client utilities:
    
```bash
sudo apt update
sudo apt install nfs-common
```
    
2.  Create a mount point for the shared directory (e.g., `/mnt/nfs`):
    
 ```bash
sudo mkdir -p /mnt/nfs
```
    
3.  Mount the NFS share:
    
```bash
sudo mount nfs_server_ip:/nfs /nfs
```

4.  To make the mount persistent across reboots, add the following line to `/etc/fstab`:
    
```bash
nfs_server_ip:/nfs /nfs nfs defaults 0 0
```

### 7. Verify the Setup

On the client servers, you can verify that the NFS share is mounted correctly:

```bash
df -h
```

You should see an entry for the NFS share. You can also test by creating a file on the NFS share and checking if it appears on the NFS server and other clients.

```bash
sudo touch /nfs/testfile
ls /nfs
```

## Troubleshooting

-   Ensure that the NFS server and clients can communicate over the network. Check firewalls and network configurations.
-   Verify that the NFS service is running on the server with `sudo systemctl status nfs-kernel-server`.
-   Check `/var/log/syslog` or `/var/log/messages` for any NFS-related error messages.

# NFS subdir external provisioner
[NFS subdir external provisioner](https://github.com/kubernetes-sigs/nfs-subdir-external-provisioner) is an automatic provisioner that use your _existing and already configured_ NFS server to support dynamic provisioning of Kubernetes Persistent Volumes via Persistent Volume Claims. Persistent volumes are provisioned as `${namespace}-${pvcName}-${pvName}`.

## Prerequisites

- A running k8s cluster.
- A configured NFS server.

## Steps

### 1. Add nfs-subdir-external-provisioner repo to helm
```bash
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
```
### 2. Helm install
```bash
helm install nfs-subdir-external-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
    --set nfs.server=x.x.x.x \
    --set nfs.path=/nfs
```
> replace x.x.x.x with your nfs server ip.
