# Immich

Self-hosted photo and video backup solution.

## Prerequisites

Before deploying via ArgoCD, complete these manual steps:

### 1. Create Namespace

```bash
kubectl create namespace immich
```

### 2. Create Database Secret

```bash
# Generate a secure password
DB_PASSWORD=$(openssl rand -base64 24)
echo "Save this password: $DB_PASSWORD"

kubectl create secret generic immich-db-secret \
  -n immich \
  --from-literal=postgres-password=$DB_PASSWORD
```

### 3. Create Immich Secrets

```bash
# Use the same DB_PASSWORD from step 2
kubectl create secret generic immich-secrets \
  -n immich \
  --from-literal=DB_URL="postgres://postgres:$DB_PASSWORD@immich-postgres:5432/immich" \
  --from-literal=JWT_SECRET=$(openssl rand -base64 32)
```

### 4. (Optional) Configure External Storage

By default, Immich uses PersistentVolumeClaims with the default StorageClass.

For NFS or external storage for photos:

```bash
# Example NFS PV (adjust for your setup)
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolume
metadata:
  name: immich-upload-pv
spec:
  capacity:
    storage: 500Gi
  accessModes:
    - ReadWriteOnce
  nfs:
    server: <your-nfs-server>
    path: /path/to/photos
EOF
```

### 5. Configure DNS

Add a DNS record pointing to your cluster:
- `immich.home-lab.begoodguys.ovh` → cluster IP

## Deployment

Once prerequisites are complete, deploy via ArgoCD:

```bash
kubectl apply -f apps/immich.yaml
```

Or let ArgoCD auto-sync if you've already registered the repository.

## Verification

```bash
# Check all pods
kubectl get pods -n immich

# Check ingress
kubectl get ingress -n immich

# Check certificate
kubectl get certificate -n immich

# Check database is ready
kubectl logs -n immich -l app=immich-postgres --tail=20
```

## Access

Open https://immich.home-lab.begoodguys.ovh

Create an admin account on first access.

## Configuration

Edit `values.yaml` to customize:

| Parameter | Description | Default |
|-----------|-------------|---------|
| `server.image.tag` | Immich server version | `v1.123.0` |
| `persistence.upload.size` | Photo storage size | `100Gi` |
| `postgresql.storage.size` | Database storage size | `10Gi` |
| `ingress.host` | Domain name | `immich.home-lab.begoodguys.ovh` |

## Architecture

```
                    ┌─────────────┐
                    │   Ingress   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │   Server    │
                    └──────┬──────┘
                           │
              ┌────────────┼────────────┐
              │            │            │
       ┌──────▼──────┐ ┌───▼───┐ ┌──────▼──────┐
       │Microservices│ │ Redis │ │ PostgreSQL  │
       └─────────────┘ └───────┘ └─────────────┘
```

## Troubleshooting

### Pods not starting
```bash
kubectl describe pod -n immich -l app=immich-server
kubectl logs -n immich -l app=immich-server
```

### Database connection issues
```bash
# Verify secret exists
kubectl get secret immich-secrets -n immich

# Check PostgreSQL logs
kubectl logs -n immich -l app=immich-postgres
```
