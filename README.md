# k8s-components-home-lab

Helm configurations for Kubernetes components running on a k3s home lab cluster.

## Prerequisites

- k3s cluster with kubectl access
- Helm 3 installed
- DNS configured for your domain

## Components

| Component | Description |
|-----------|-------------|
| [cert-manager](./cert-manager/) | Automated TLS certificate management with Let's Encrypt |
| [argocd](./argocd/) | GitOps continuous delivery |

## Installation Order

1. **cert-manager** - Required for TLS certificates
2. **argocd** - Depends on cert-manager for HTTPS

Follow the README in each component directory for installation instructions.
