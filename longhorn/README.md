# Longhorn

Distributed block storage for Kubernetes, providing persistent volumes for applications.

## Prerequisites

- Helm 3 installed
- kubectl configured to access your cluster
- cert-manager installed with ClusterIssuer configured (see `../cert-manager/`) - required for SSL ingress
- Traefik ingress controller (comes with k3s by default)
- All cluster nodes must have `open-iscsi` installed (required for Longhorn)
- All cluster nodes must have `nfs-utils` installed (required for Longhorn RWX volumes)

### Install open-iscsi on cluster nodes

Use the Ansible playbook in the `ansible-kubernetes-home-lab` repository to install `open-iscsi` on all nodes:

```bash
# From the ansible-kubernetes-home-lab repository
ansible-playbook install-open-iscsi.yml -i inventory.yml
```

This playbook automatically handles the mixed OS environment:
- **Arch Linux** (server nodes with Longhorn storage): Installs via `pacman`
- **Raspbian** (agent nodes): Installs via `apt`

The playbook installs `open-iscsi` on all cluster nodes and enables the `iscsid` service, which is required for Longhorn to function properly.

### Install nfs-utils on cluster nodes

Longhorn requires `nfs-utils` (or `nfs-common` on Debian/Raspbian) for ReadWriteMany (RWX) volume support:

```bash
# From the ansible-kubernetes-home-lab repository
ansible-playbook install-nfs-utils.yml -i inventory.yml
```

This playbook automatically handles the mixed OS environment:
- **Arch Linux** (server nodes): Installs `nfs-utils` via `pacman`
- **Raspbian** (agent nodes): Installs `nfs-common` via `apt`

The playbook installs the NFS utilities and enables the `rpcbind` service, which is required for Longhorn to create disks on nodes.

### External SSD Setup (Optional but Recommended)

If you want to mount an external SSD to `/var/lib/longhorn` for better performance and capacity, see [EXTERNAL_DISK_SETUP.md](./EXTERNAL_DISK_SETUP.md) for detailed instructions and troubleshooting.

**Quick fix if space isn't appearing:**
1. Verify the mount: `df -h /mnt/longhorn` on each node
2. Upgrade Longhorn with updated values.yaml or manually add disk in UI
3. Restart Longhorn manager: `kubectl rollout restart deployment/longhorn-manager -n longhorn-system`
4. Check Longhorn UI → Nodes → Edit Disks to verify `/mnt/longhorn` is detected

### Label Storage Nodes

Label the server nodes (master nodes with SSDs) so Longhorn only uses them for storage:

```bash
# From the ansible-kubernetes-home-lab repository
ansible-playbook label-storage-nodes.yml -i inventory.yml
```

This labels all server nodes with `storage-node=true`. The Longhorn Helm chart is configured to only use nodes with this label, excluding agent nodes (Raspbian) which don't have sufficient storage speed.

### Load dm_crypt Kernel Modules (Optional)

If you see a warning in Longhorn UI about "Kernel modules [dm_crypt] are not loaded", you can optionally load them to enable Longhorn's volume encryption feature:

```bash
# From the ansible-kubernetes-home-lab repository
ansible-playbook load-dm-crypt-modules.yml -i inventory.yml
```

**Note:** This is only required if you plan to use encrypted volumes. If you don't need encryption, you can safely ignore the warning. The playbook loads the modules and configures them to load automatically on boot.

## Installation

### 1. Add Helm repository

```bash
helm repo add longhorn https://charts.longhorn.io
helm repo update
```

### 2. Install Longhorn

```bash
helm install longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --create-namespace \
  --version 1.10.1 \
  -f values.yaml
```

**Note:** The chart version is pinned to `1.10.1` (latest stable). Update this version when upgrading Longhorn.

### 3. Verify installation

```bash
# Check pods
kubectl get pods -n longhorn-system

# Wait for all pods to be Running
kubectl wait --for=condition=ready pod --all -n longhorn-system --timeout=300s

# Check storage class
kubectl get storageclass
```

You should see `longhorn` as the default storage class (or set it as default if needed).

### 4. Set Longhorn as default storage class (if not already)

```bash
# Remove default annotation from other storage classes
kubectl patch storageclass <other-storage-class> -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'

# Set Longhorn as default
kubectl patch storageclass longhorn -p '{"metadata": {"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

### 5. Configure DNS

Add a DNS record pointing to your cluster:
- `longhorn.home-lab.begoodguys.ovh` → cluster IP

### 6. Set up Ingress with SSL (Recommended)

After Longhorn is installed and running, apply the ingress manifest to expose the UI via HTTPS:

```bash
kubectl apply -f ingress.yaml
```

This creates an ingress that:
- Exposes Longhorn UI at `https://longhorn.home-lab.begoodguys.ovh`
- Uses cert-manager with DNS-01 challenge (OVH) for automatic SSL certificate
- Uses Traefik as the ingress controller

**Verify ingress and certificate:**

```bash
# Check ingress
kubectl get ingress -n longhorn-system

# Check certificate status
kubectl get certificate -n longhorn-system

# Wait for certificate to be ready
kubectl wait --for=condition=ready certificate longhorn-ui-tls -n longhorn-system --timeout=300s
```

Once the certificate is ready, access the UI at: **https://longhorn.home-lab.begoodguys.ovh**

### 7. Access Longhorn UI (Alternative: Port Forward)

If you prefer port forwarding instead of ingress:

```bash
# Port forward to access UI
kubectl port-forward -n longhorn-system svc/longhorn-frontend 8080:80
```

Open http://localhost:8080 in your browser.

## Upgrade

```bash
helm repo update
helm upgrade longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --version 1.10.1 \
  -f values.yaml
```

**Note:** Update the `--version` flag to the desired Longhorn version. Check [Longhorn releases](https://github.com/longhorn/longhorn/releases) for the latest version.

## Uninstall

```bash
helm uninstall longhorn -n longhorn-system
kubectl delete namespace longhorn-system
```

**Warning**: Uninstalling Longhorn will delete all persistent volumes. Backup your data first!
