# k8s-components-home-lab

Kubernetes configurations for a k3s home lab cluster, managed via ArgoCD GitOps.

## Prerequisites

- k3s cluster with kubectl access
- Helm 3 installed
- DNS configured for your domain (`*.home-lab.begoodguys.ovh`)

## Repository Structure

```
k8s-components-home-lab/
├── longhorn/         # Longhorn Helm configuration
├── cert-manager/     # cert-manager Helm configuration
├── argocd/           # ArgoCD Helm configuration
├── apps/             # ArgoCD Application manifests
├── manifests/        # Plain YAML Kubernetes manifests
└── charts/           # Custom Helm charts
```

## Infrastructure Components

| Component | Description | Type | URL |
|-----------|-------------|------|-----|
| [longhorn](./longhorn/) | Distributed block storage for persistent volumes | Helm | https://longhorn.home-lab.begoodguys.ovh |
| [cert-manager](./cert-manager/) | Automated TLS certificate management with Let's Encrypt | Helm | - |
| [argocd](./argocd/) | GitOps continuous delivery | Helm | https://argocd.home-lab.begoodguys.ovh |

## Applications

| Application | Description | Type | URL |
|-------------|-------------|------|-----|
| [jellyfin](./manifests/jellyfin/) | Media server for movies, TV, music | Plain YAML | https://jellyfin.home-lab.begoodguys.ovh:8443 |
| [qbittorrent](./manifests/qbittorrent/) | BitTorrent client with web UI | Plain YAML | https://qbittorrent.home-lab.begoodguys.ovh |
| [immich](./charts/immich/) | Self-hosted photo/video backup | Helm Chart | https://immich.home-lab.begoodguys.ovh |

## Installation Order

### 1. Infrastructure (manual Helm install)

**Important**: Install components in this order, as each depends on the previous:

```bash
# 1. Install Longhorn first (provides storage for all applications)
cd longhorn && helm install ...
# After installation, apply ingress: kubectl apply -f longhorn/ingress.yaml

# 2. Install cert-manager (provides TLS certificates)
cd cert-manager && helm install ...

# 3. Install ArgoCD (GitOps tool for managing applications)
cd argocd && helm install ...
```

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
