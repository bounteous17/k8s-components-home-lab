# Jellyfin

Media server for streaming movies, TV shows, music, and more.

## Prerequisites

Before deploying via ArgoCD, complete these manual steps:

### 1. Install Longhorn (if not already installed)

Jellyfin requires persistent storage. Ensure Longhorn is installed and configured as the default storage class:

```bash
# See ../longhorn/README.md for installation instructions
# Verify Longhorn storage class exists
kubectl get storageclass
```

### 2. Create Namespace

```bash
kubectl create namespace jellyfin
```

### 3. Configure NFS Export on Octopus Node

First, configure the NFS export on the octopus node (192.168.11.51):

```bash
# From the ansible-kubernetes-home-lab repository
ansible-playbook configure-nfs-export.yml -i inventory.yml --limit 192.168.11.51
```

This exports `/mnt/nas-kingston` from the octopus node to all network addresses.

### 4. Create NFS PersistentVolume for Media

Jellyfin media storage uses the NFS export from the octopus node. Create the PersistentVolume:

```bash
kubectl apply -f manifests/jellyfin/pv.yaml
```

This creates a PersistentVolume pointing to:
- **NFS Server**: `192.168.11.51` (octopus node)
- **NFS Path**: `/mnt/nas-kingston`

### 5. Configure DNS

Add a DNS record pointing to your cluster:
- `jellyfin.home-lab.begoodguys.ovh` → cluster IP

## Deployment

Once prerequisites are complete, deploy via ArgoCD:

```bash
kubectl apply -f apps/jellyfin.yaml
```

Or let ArgoCD auto-sync if you've already registered the repository.

## Verification

```bash
# Check pods
kubectl get pods -n jellyfin

# Check service (should show NodePort 8443)
kubectl get svc -n jellyfin

# Check service details
kubectl describe svc jellyfin -n jellyfin
```

## Access

Jellyfin is exposed via NodePort on port **30843** (Kubernetes NodePort range: 30000-32767).

**Router Configuration**: Configure your router to forward external port **8443** to internal port **30843** on your cluster nodes.

Access Jellyfin at:
- **From internet**: `https://<your-router-ip>:8443` or `https://jellyfin.home-lab.begoodguys.ovh:8443` (router forwards 8443 → 30843)
- **From local network**: `http://<cluster-node-ip>:30843` or `https://jellyfin.home-lab.begoodguys.ovh:8443`

**Note**: 
- Kubernetes NodePort range is 30000-32767, so we use 30843 internally
- Your router should forward external port 8443 to internal port 30843
- SSL/TLS can be handled at the router level or by Jellyfin's built-in SSL configuration

Initial setup will guide you through creating an admin account.

## Configuration

### Storage

- `jellyfin-config`: Configuration and metadata (default: 10Gi, dynamically provisioned via Longhorn)
- `jellyfin-media`: Media files (NFS mount from octopus node at `/mnt/nas-kingston`, ReadWriteMany access mode)

The media library is stored on the NFS export from the octopus node (192.168.11.51). The volume is configured with `ReadWriteMany` access mode, which allows multiple pods to mount it simultaneously for reading. Since Jellyfin runs as a single pod, there's no risk of concurrent write conflicts - only the Jellyfin pod will write to the media library.

### Resource Limits

Edit `deployment.yaml` to adjust CPU/memory limits based on your cluster capacity.
