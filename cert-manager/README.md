# cert-manager

Automated TLS certificate management for Kubernetes using Let's Encrypt.

## Challenge Types

Let's Encrypt requires domain validation before issuing certificates. There are two methods:

| Method | How it works | Pros | Cons |
|--------|--------------|------|------|
| **HTTP-01** | Let's Encrypt connects to port 80 on your server | Simple setup | Requires public port 80 |
| **DNS-01** | Proves ownership via DNS TXT record | No public ports needed | Requires DNS provider API |

### Why we use DNS-01 with OVH webhook

For a homelab behind a firewall/VPN, **DNS-01 is the better choice**:

1. **Security**: No need to expose ports 80/443 to the public internet
2. **VPN-friendly**: Services can remain accessible only via WireGuard VPN
3. **Firewall-friendly**: MikroTik can block all inbound WAN traffic while certificates still renew
4. **Wildcard support**: DNS-01 can issue wildcard certificates (`*.home-lab.begoodguys.ovh`)

Since our domain is managed by OVH, we use `cert-manager-webhook-ovh` to automate DNS record creation during certificate issuance and renewal.

## Prerequisites

- Helm 3 installed
- kubectl configured to access your cluster
- OVH API credentials (for DNS-01 challenge)

## Installation

### 1. Add Helm repositories

```bash
helm repo add jetstack https://charts.jetstack.io
helm repo add cert-manager-webhook-ovh https://aureq.github.io/cert-manager-webhook-ovh
helm repo update
```

### 2. Install cert-manager

```bash
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version v1.19.2 \
  -f values.yaml
```

### 3. Verify cert-manager is running

```bash
kubectl get pods -n cert-manager
```

All pods should be in `Running` state.

### 4. Create OVH API credentials

Go to https://eu.api.ovh.com/createToken/ and create credentials with these permissions:

- **GET** `/domain/zone/*`
- **POST** `/domain/zone/*`
- **DELETE** `/domain/zone/*`

### 5. Create OVH credentials secret

```bash
kubectl create secret generic ovh-credentials -n cert-manager \
  --from-literal=applicationKey='YOUR_APP_KEY' \
  --from-literal=applicationSecret='YOUR_APP_SECRET' \
  --from-literal=consumerKey='YOUR_CONSUMER_KEY'
```

### 6. Install cert-manager-webhook-ovh

This webhook enables DNS-01 challenges via OVH API and creates the ClusterIssuers:

```bash
helm install cert-manager-webhook-ovh cert-manager-webhook-ovh/cert-manager-webhook-ovh \
  --namespace cert-manager \
  -f webhook-ovh-values.yaml
```

### 7. Verify ClusterIssuers

```bash
kubectl get clusterissuer
```

Both `letsencrypt-staging` and `letsencrypt-prod` should show `Ready=True`.

## Usage

Add annotation to your Ingress to request certificates:

```yaml
annotations:
  cert-manager.io/cluster-issuer: letsencrypt-prod
```

Use `letsencrypt-staging` first for testing (avoids rate limits), then switch to `letsencrypt-prod`.

## Upgrade

```bash
helm upgrade cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  -f values.yaml

helm upgrade cert-manager-webhook-ovh cert-manager-webhook-ovh/cert-manager-webhook-ovh \
  --namespace cert-manager \
  -f webhook-ovh-values.yaml
```

## Uninstall

```bash
helm uninstall cert-manager-webhook-ovh -n cert-manager
helm uninstall cert-manager -n cert-manager
kubectl delete namespace cert-manager
```
