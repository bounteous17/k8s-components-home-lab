# k8s-components-home-lab

Kubernetes configurations for a k3s home lab cluster, managed via ArgoCD GitOps.

## Prerequisites

- k3s cluster with kubectl access
- Helm 3 installed
- DNS configured for your domain (`*.home-lab.begoodguys.ovh`)
- Apply IPWhitelist middleware before deploying internal services (see [middlewares](./middlewares/))

## Repository Structure

```
k8s-components-home-lab/
├── longhorn/         # Longhorn Helm configuration
├── cert-manager/     # cert-manager Helm configuration
├── argocd/           # ArgoCD Helm configuration
├── middlewares/      # Traefik middleware configurations
├── apps/             # ArgoCD Application manifests
├── manifests/        # Plain YAML Kubernetes manifests
└── charts/           # Custom Helm charts
```

## Infrastructure Components

| Component | Description | Type | Access |
|-----------|-------------|------|--------|
| [longhorn](./longhorn/) | Distributed block storage for persistent volumes | Helm | Internal networks only (https://longhorn.home-lab.begoodguys.ovh) |
| [cert-manager](./cert-manager/) | Automated TLS certificate management with Let's Encrypt | Helm | - |
| [argocd](./argocd/) | GitOps continuous delivery | Helm | Internal networks only (https://argocd.home-lab.begoodguys.ovh) |

## Applications

| Application | Description | Type | Access |
|-------------|-------------|------|--------|
| [jellyfin](./manifests/jellyfin/) | Media server for movies, TV, music | Plain YAML | Public (https://jellyfin.home-lab.begoodguys.ovh) |
| [qbittorrent](./manifests/qbittorrent/) | BitTorrent client with web UI | Plain YAML | Internal networks only (https://qbittorrent.home-lab.begoodguys.ovh) |
| [immich](./charts/immich/) | Self-hosted photo/video backup | Helm Chart | https://immich.home-lab.begoodguys.ovh |

## Installation Order

### 1. Infrastructure (manual Helm install)

**Important**: Install components in this order, as each depends on the previous:

```bash
# 1. Install Longhorn first (provides storage for all applications)
cd longhorn && helm install ...

# 2. Install cert-manager (provides TLS certificates)
cd cert-manager && helm install ...

# 3. Apply IPWhitelist middleware (restricts internal services to internal networks)
kubectl apply -f middlewares/ipwhitelist-internal.yaml

# 4. Install ArgoCD (GitOps tool for managing applications)
cd argocd && helm install ...
```

**Note**: Longhorn and ArgoCD are accessible via HTTPS with SSL at their domain names, but access is restricted to internal networks only (192.168.*.* and 10.255.255.*). They are not exposed to the internet. See their respective README files for details.

Follow the README in each directory for detailed instructions.

### 2. Applications (via ArgoCD)

Once ArgoCD is running, deploy applications via GitOps:

```bash
# Connect ArgoCD to this repository
argocd repo add https://github.com/alexserra98/k8s-components-home-lab.git

# Deploy Jellyfin (see manifests/jellyfin/README.md for prerequisites)
kubectl apply -f apps/jellyfin.yaml

# Deploy qBittorrent (see manifests/qbittorrent/README.md for prerequisites)
kubectl apply -f apps/qbittorrent.yaml

# Deploy Immich (see charts/immich/README.md for prerequisites)
kubectl apply -f apps/immich.yaml
```

Each application has manual prerequisites (secrets, DNS). Check the README in each app directory before deploying.

## Adding New Applications

- **Simple apps** (single container): Add plain YAML to `manifests/<app-name>/`
- **Complex apps** (multiple components): Add Helm chart to `charts/<app-name>/`
- **ArgoCD Application**: Add manifest to `apps/<app-name>.yaml`
