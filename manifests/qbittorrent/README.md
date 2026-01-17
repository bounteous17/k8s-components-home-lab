# qBittorrent

BitTorrent client with web UI for downloading torrents to the NFS media share.

## Prerequisites

Before deploying via ArgoCD, complete these manual steps:

- cert-manager installed with ClusterIssuer configured (see `../cert-manager/`) - required for SSL ingress
- Traefik ingress controller (comes with k3s by default)
- DNS configured to point `qbittorrent.home-lab.begoodguys.ovh` to your cluster

### 1. NFS PersistentVolume

qBittorrent uses the same NFS export as Jellyfin for downloads. Create the PersistentVolume:

```bash
kubectl apply -f manifests/qbittorrent/pv.yaml
```

This creates a PersistentVolume pointing to:
- **NFS Server**: `192.168.11.51` (octopus node)
- **NFS Path**: `/mnt/nas-kingston` (same as Jellyfin)

### 2. Create Namespace

```bash
kubectl create namespace qbittorrent
```

### 3. Configure DNS

Add a DNS record pointing to your cluster:
- `qbittorrent.home-lab.begoodguys.ovh` → cluster IP

## Deployment

Once prerequisites are complete, deploy via ArgoCD:

```bash
kubectl apply -f apps/qbittorrent.yaml
```

Or let ArgoCD auto-sync if you've already registered the repository.

## Access

qBittorrent is exposed via Ingress with TLS at `https://qbittorrent.home-lab.begoodguys.ovh`.

**After deployment, verify ingress and certificate:**

```bash
# Check ingress
kubectl get ingress -n qbittorrent

# Check certificate status
kubectl get certificate -n qbittorrent

# Wait for certificate to be ready
kubectl wait --for=condition=ready certificate qbittorrent-tls -n qbittorrent --timeout=300s
```

Once the certificate is ready, access qBittorrent at: **https://qbittorrent.home-lab.begoodguys.ovh**

**Note**: The ingress uses cert-manager with DNS-01 challenge (OVH) for automatic SSL certificate issuance.

## Initial Setup

1. **Default credentials**:
   - Username: `admin`
   - Password: `adminadmin`

2. **Change password immediately**:
   - Go to **Tools** → **Options** → **Web UI**
   - Change the admin password

3. **Configure reverse proxy settings** (if needed):
   - Go to **Tools** → **Options** → **Web UI**
   - Under "Security", you may need to disable "Host header validation" if you encounter issues
   - The deployment already sets `WEBUI_HOST_HEADER_VALIDATION=false` for Traefik compatibility

4. **Configure download location**:
   - Go to **Tools** → **Options** → **Downloads**
   - Default download path: `/downloads`
   - This is mounted to the NFS share (`/mnt/nas-kingston` on octopus node)

5. **Organize downloads** (recommended):
   - Create subdirectories in the NFS share:
     ```bash
     # On octopus node (192.168.11.51)
     sudo mkdir -p /mnt/nas-kingston/downloads/{movies,tv-shows,music,other}
     ```
   - In qBittorrent, set default save path to `/downloads/downloads/movies` for movies, etc.

## Port Configuration

- **Web UI**: Accessible via HTTPS ingress at `qbittorrent.home-lab.begoodguys.ovh`
- **BitTorrent**: Port 6881 (TCP/UDP) - internal cluster port
  - For external BitTorrent access, configure port forwarding on your router
  - Or use UPnP if your router supports it (enable in qBittorrent settings)
  - In qBittorrent settings, configure the listening port and enable UPnP/NAT-PMP

## Integration with Jellyfin

Downloads go directly to `/downloads` which is the same NFS mount as Jellyfin's `/media`:
- qBittorrent downloads to: `/downloads` → `/mnt/nas-kingston` on octopus node
- Jellyfin reads from: `/media` → `/mnt/nas-kingston` on octopus node

**Workflow:**
1. Download torrents in qBittorrent to `/downloads/downloads/movies/`
2. Move/organize files to `/downloads/movies/` (or use qBittorrent's category feature)
3. Jellyfin automatically scans and adds to library

## Verification

```bash
# Check pods
kubectl get pods -n qbittorrent

# Check service
kubectl get svc -n qbittorrent

# Check ingress
kubectl get ingress -n qbittorrent

# Check certificate
kubectl get certificate -n qbittorrent

# Check PVCs
kubectl get pvc -n qbittorrent

# Check logs
kubectl logs -n qbittorrent -l app=qbittorrent
```

## Configuration

### Storage

- `qbittorrent-config`: Configuration and settings (default: 5Gi, dynamically provisioned via Longhorn)
- `qbittorrent-downloads`: Downloads directory (NFS mount from octopus node at `/mnt/nas-kingston`, ReadWriteMany access mode)

### Resource Limits

Edit `deployment.yaml` to adjust CPU/memory limits based on your cluster capacity.

### Environment Variables

- `PUID`: User ID (default: 1000)
- `PGID`: Group ID (default: 1000)
- `TZ`: Timezone (default: Europe/Paris, change as needed)
- `WEBUI_PORT`: Web UI port (default: 8080)
