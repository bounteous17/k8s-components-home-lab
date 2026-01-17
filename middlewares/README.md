# Traefik Middlewares

This directory contains Traefik middleware configurations for access control and other routing features.

## IPWhitelist Middleware

The `ipwhitelist-internal.yaml` middleware restricts access to internal network IP ranges:

- `192.168.0.0/16` - Mikrotik router internal network
- `10.255.255.0/24` - Mikrotik router internal network

### Usage

Apply the middleware before deploying services that need internal-only access:

```bash
kubectl apply -f middlewares/ipwhitelist-internal.yaml
```

### Applying to Ingress Resources

Reference this middleware in your ingress annotations:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    traefik.ingress.kubernetes.io/router.middlewares: default-ipwhitelist-internal@kubernetescrd
spec:
  # ... rest of ingress config
```

### Services Using This Middleware

- ArgoCD (`argocd.home-lab.begoodguys.ovh`)
- Longhorn (`longhorn.home-lab.begoodguys.ovh`)
- qBittorrent (`qbittorrent.home-lab.begoodguys.ovh`)

These services are accessible via HTTPS with SSL certificates, but only from devices on the internal network ranges specified above. External IPs will be blocked.
