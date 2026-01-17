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

### 3. Create NFS PersistentVolume for Media

Jellyfin media storage uses an existing NFS mount. Create the PersistentVolume:

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: jellyfin-media-pv
spec:
  capacity:
    storage: 1Ti
  accessModes:
    - ReadWriteMany
  persistentVolumeReclaimPolicy: Retain
  nfs:
    server: <your-nfs-server>       # e.g., 192.168.1.100
    path: <your-nfs-export-path>    # e.g., /mnt/media/jellyfin
EOF
```

Replace `<your-nfs-server>` and `<your-nfs-export-path>` with your NFS configuration.

### 4. Configure DNS

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

Jellyfin is exposed via NodePort on port **8443** (configured to match your router's exposed port).

Access Jellyfin at:
- **From internet**: `https://<your-router-ip>:8443` or `https://jellyfin.home-lab.begoodguys.ovh:8443`
- **From local network**: `http://<cluster-node-ip>:8443` or `https://jellyfin.home-lab.begoodguys.ovh:8443`

**Note**: Port 8443 is used because it's the only port your router exposes to the internet. SSL/TLS can be handled at the router level or by Jellyfin's built-in SSL configuration.

Initial setup will guide you through creating an admin account.

## Configuration

### Storage

- `jellyfin-config`: Configuration and metadata (default: 10Gi, dynamically provisioned)
- `jellyfin-media`: Media files (NFS mount, create PV manually - see prerequisites)

### Resource Limits

Edit `deployment.yaml` to adjust CPU/memory limits based on your cluster capacity.
