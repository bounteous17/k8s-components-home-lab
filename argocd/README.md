# ArgoCD

GitOps continuous delivery tool for Kubernetes.

## Prerequisites

- Helm 3 installed
- kubectl configured to access your cluster
- cert-manager installed with ClusterIssuer configured (see `../cert-manager/`)
- DNS configured to point `argocd.home-lab.begoodguys.ovh` to your cluster
- IPWhitelist middleware applied (see `../middlewares/ipwhitelist-internal.yaml`)

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

### 4. Apply IPWhitelist Middleware

Apply the IPWhitelist middleware to restrict access to internal networks:

```bash
kubectl apply -f ../middlewares/ipwhitelist-internal.yaml
```

This restricts access to IPs in the ranges:
- `192.168.0.0/16` (Mikrotik router internal network)
- `10.255.255.0/24` (Mikrotik router internal network)

### 5. Check certificate

```bash
kubectl get certificate -n argocd
```

Should show `Ready=True` once cert-manager issues the certificate.

### 6. Check ingress

```bash
kubectl get ingress -n argocd
```

Should show an ADDRESS assigned.

## Access ArgoCD

**ArgoCD is accessible via HTTPS with SSL, but restricted to internal networks only** (not exposed to the internet for security reasons).

### Get admin password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Access from Internal Networks

ArgoCD is exposed via Ingress with TLS at `https://argocd.home-lab.begoodguys.ovh`.

**Access is restricted to internal IP ranges:**
- `192.168.*.*` (Mikrotik router internal network)
- `10.255.255.*` (Mikrotik router internal network)

**Note**: Access from external IPs will be blocked by the IPWhitelist middleware.

### Login

1. Open https://argocd.home-lab.begoodguys.ovh (from devices on internal networks)
2. Username: `admin`
3. Password: (from command above)

### Alternative Access Method: Port Forward

If you need to access ArgoCD from outside the internal network:

```bash
# Port forward to access ArgoCD UI
kubectl port-forward -n argocd svc/argocd-server 8080:80
```

Then open http://localhost:8080 in your browser.

**Note**: ArgoCD runs in insecure mode (TLS terminated at ingress), so when using port-forward, you'll access it via HTTP on port 80.

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
