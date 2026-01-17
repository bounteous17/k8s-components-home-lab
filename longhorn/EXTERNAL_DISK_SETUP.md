# Longhorn External SSD Setup Guide

## Is it Good Practice?

**Yes!** Mounting Longhorn storage on an external SSD is a best practice because:
- Better performance (SSD vs HDD)
- Separates storage from system disk
- Prevents root filesystem from filling up
- Allows for larger storage capacity

## Current Configuration

The cluster is configured to use `/mnt/longhorn` as the storage path (mounted external SSD).

## Setup Steps

### 1. Format and Mount the SSD

On each node with an external SSD:

```bash
# Find the disk (usually /dev/sdb, /dev/sdc, etc.)
lsblk

# Format with ext4 (Longhorn requires ext4 or xfs)
sudo mkfs.ext4 /dev/sdX

# Create mount point (if not exists)
sudo mkdir -p /mnt/longhorn

# Mount the disk
sudo mount /dev/sdX /mnt/longhorn

# Verify mount
df -h /mnt/longhorn
```

### 2. Make Mount Persistent

Add to `/etc/fstab` so it survives reboots:

```bash
# Get UUID of the disk
sudo blkid /dev/sdX

# Add to /etc/fstab (replace UUID with actual UUID)
echo "UUID=<your-uuid> /mnt/longhorn ext4 defaults 0 2" | sudo tee -a /etc/fstab

# Test fstab
sudo mount -a
```

### 3. Set Correct Permissions

Longhorn needs to write to this directory:

```bash
sudo chown -R root:root /mnt/longhorn
sudo chmod 755 /mnt/longhorn
```

### 4. Restart Longhorn Manager (if needed)

After mounting, Longhorn should auto-detect the disk. If not:

```bash
# Restart Longhorn manager pods to detect new disk
kubectl rollout restart deployment/longhorn-manager -n longhorn-system

# Wait for pods to restart
kubectl wait --for=condition=ready pod -l app=longhorn-manager -n longhorn-system --timeout=300s
```

### 5. Apply Configuration Change

Since you've changed the mount point to `/mnt/longhorn`, you need to update Longhorn:

**Option A: Upgrade Longhorn with new values.yaml** (Recommended)
```bash
cd longhorn
helm upgrade longhorn longhorn/longhorn \
  --namespace longhorn-system \
  --version 1.10.1 \
  -f values.yaml
```

**Option B: Manually add disk in Longhorn UI**
1. Go to Longhorn UI → **Nodes**
2. Click on a node → **Edit Disks**
3. Add new disk:
   - **Path**: `/mnt/longhorn`
   - **Allow Scheduling**: ✅ Enabled
4. Optionally disable scheduling on `/var/lib/longhorn` if it exists

### 6. Verify in Longhorn UI

1. Go to Longhorn UI → **Nodes**
2. Click on a node
3. Check **Disks** section
4. You should see `/mnt/longhorn` with available space

## Troubleshooting: No Space Appearing

If space isn't appearing after mounting:

### Check 1: Verify Mount is Active

```bash
# On each node
df -h /mnt/longhorn
mount | grep longhorn
```

### Check 2: Verify Longhorn Can Access the Path

```bash
# Check Longhorn manager logs
kubectl logs -n longhorn-system -l app=longhorn-manager | grep -i "disk\|mount\|/mnt/longhorn"
```

### Check 3: Check Node Disk Status

```bash
# Get node name
kubectl get nodes

# Check Longhorn node resource
kubectl get node.longhorn.io <node-name> -n longhorn-system -o yaml
```

### Check 4: Manually Add Disk in Longhorn UI

If auto-detection doesn't work:

1. Go to Longhorn UI → **Nodes**
2. Click on the node
3. Click **Edit Disks**
4. Verify `/mnt/longhorn` is listed
5. If not, add it manually:
   - **Path**: `/mnt/longhorn`
   - **Allow Scheduling**: ✅ Enabled
   - **Storage Reserved**: Leave default or set to 0
6. Click **Save**

### Check 5: Verify Filesystem Type

Longhorn requires `ext4` or `xfs`:

```bash
# Check filesystem type
df -T /mnt/longhorn
```

### Check 6: Check for Permission Issues

```bash
# Test if Longhorn can access
sudo -u root ls -la /mnt/longhorn
```

## Alternative: Add as Separate Disk

Instead of mounting to `/var/lib/longhorn`, you can mount to a different path and add it as a separate disk:

1. Mount SSD to `/mnt/longhorn-ssd` (or any path)
2. In Longhorn UI → Nodes → Edit Disks
3. Add new disk:
   - **Path**: `/mnt/longhorn-ssd`
   - **Allow Scheduling**: ✅ Enabled
4. Optionally disable scheduling on default path

## Ansible Playbook

For automated setup across all nodes, see `ansible-kubernetes-home-lab/mount-longhorn-disk.yml` (if created).
