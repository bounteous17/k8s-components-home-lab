# ArgoCD

GitOps continuous delivery tool for Kubernetes.

## Prerequisites

- Helm 3 installed
- kubectl configured to access your cluster
- cert-manager installed with ClusterIssuer configured (see `../cert-manager/`)
- DNS configured to point `argocd.home-lab.begoodguys.ovh` to your cluster

## Installation

### 1. Add the Helm repository

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

### 2. Install ArgoCD

```bash
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --version 9.3.3 \
  -f values.yaml
```

### 3. Verify installation

```bash
kubectl get pods -n argocd
```

All pods should be in `Running` state.

### 4. Check certificate

```bash
kubectl get certificate -n argocd
```

Should show `Ready=True` once cert-manager issues the certificate.

### 5. Check ingress

```bash
kubectl get ingress -n argocd
```

Should show an ADDRESS assigned.

## Access ArgoCD

### Get admin password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Login

1. Open https://argocd.home-lab.begoodguys.ovh
2. Username: `admin`
3. Password: (from command above)

## Upgrade

```bash
helm upgrade argocd argo/argo-cd \
  --namespace argocd \
  -f values.yaml
```

## Uninstall

```bash
helm uninstall argocd -n argocd
kubectl delete namespace argocd
```
