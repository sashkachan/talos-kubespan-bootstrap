#!/bin/bash
set -e

# Create etcd snapshots for each control plane node separately
#
# Usage: etcd_snapshot.sh
#
# This script:
# 1. Loads environment from cluster configuration
# 2. Creates etcd snapshots for each control plane node
# 3. Saves snapshots with timestamps and node identification

# Load environment
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
GENERATED_DIR="$SCRIPT_DIR/generated"
TALOS_CONFIG_PATH="$GENERATED_DIR/talosconfig"

# Check if talosconfig exists
if [ ! -f "$TALOS_CONFIG_PATH" ]; then
    echo "Error: talosconfig not found at $TALOS_CONFIG_PATH"
    echo "Run 'make talos-generate-configs' first."
    exit 1
fi

# Check if cluster_info.env exists to get node information
if [ ! -f "$GENERATED_DIR/cluster_info.env" ]; then
    echo "Error: cluster_info.env not found. Cannot determine control plane nodes."
    exit 1
fi

# Source cluster info
source "$GENERATED_DIR/cluster_info.env"

# Create snapshots directory if it doesn't exist
SNAPSHOT_DIR="$GENERATED_DIR/etcd-snapshots"
mkdir -p "$SNAPSHOT_DIR"

# Generate timestamp for this backup session
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

echo "Creating etcd snapshots for all control plane nodes..."
echo "Snapshot directory: $SNAPSHOT_DIR"

# Get control plane node IPs (stored as NODE_IPS in cluster_info.env)
CONTROL_PLANE_IPS=($(echo "$NODE_IPS" | tr ' ' '\n'))

if [ ${#CONTROL_PLANE_IPS[@]} -eq 0 ]; then
    echo "Error: No control plane IPs found in cluster_info.env"
    exit 1
fi

# Create snapshot for each control plane node
for i in "${!CONTROL_PLANE_IPS[@]}"; do
    NODE_IP="${CONTROL_PLANE_IPS[$i]}"
    NODE_NUMBER=$((i + 1))
    SNAPSHOT_FILE="$SNAPSHOT_DIR/etcd-snapshot-cp${NODE_NUMBER}-${TIMESTAMP}.db"
    
    echo "Creating snapshot for control plane node $NODE_NUMBER (IP: $NODE_IP)..."
    
    if TALOSCONFIG="$TALOS_CONFIG_PATH" talosctl -n "$NODE_IP" -e "$NODE_IP" etcd snapshot "$SNAPSHOT_FILE"; then
        echo "✓ Snapshot created: $(basename "$SNAPSHOT_FILE")"
        
        # Get snapshot info
        SNAPSHOT_SIZE=$(du -h "$SNAPSHOT_FILE" | cut -f1)
        echo "  Size: $SNAPSHOT_SIZE"
    else
        echo "✗ Failed to create snapshot for node $NODE_IP"
    fi
    
    echo ""
done

echo "Etcd snapshot backup completed!"
echo "Snapshots saved in: $SNAPSHOT_DIR"
echo ""
echo "Available snapshots:"
ls -lh "$SNAPSHOT_DIR"/*.db 2>/dev/null || echo "No snapshots found"