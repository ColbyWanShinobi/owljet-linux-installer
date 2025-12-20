#!/bin/bash
# Script to create a swap file on btrfs subvolume
# This should run in the chroot environment after installation

set -e

# Function to log messages
log() {
    echo "[swap-file] $1"
}

log "Setting up swap file..."

# Determine swap size based on RAM
TOTAL_RAM=$(free -m | awk '/^Mem:/{print $2}')
log "Total RAM: ${TOTAL_RAM}MB"

# Calculate swap size
# If RAM <= 2GB: swap = 2 * RAM
# If RAM <= 8GB: swap = RAM
# If RAM > 8GB: swap = 8GB (for hibernate) or 4GB (without hibernate)
if [ "$TOTAL_RAM" -le 2048 ]; then
    SWAP_SIZE=$((TOTAL_RAM * 2))
elif [ "$TOTAL_RAM" -le 8192 ]; then
    SWAP_SIZE=$TOTAL_RAM
else
    # Default to 8GB for systems with more RAM (allows hibernate)
    SWAP_SIZE=8192
fi

log "Calculated swap size: ${SWAP_SIZE}MB"

# Create swap directory if it doesn't exist
SWAP_DIR="/swap"
if [ ! -d "$SWAP_DIR" ]; then
    log "Creating $SWAP_DIR directory..."
    mkdir -p "$SWAP_DIR"
fi

# Check if we're on btrfs
FS_TYPE=$(stat -f -c %T "$SWAP_DIR" 2>/dev/null || echo "unknown")
log "Filesystem type for $SWAP_DIR: $FS_TYPE"

SWAP_FILE="$SWAP_DIR/swapfile"

# Remove existing swap file if it exists
if [ -f "$SWAP_FILE" ]; then
    log "Removing existing swap file..."
    swapoff "$SWAP_FILE" 2>/dev/null || true
    rm -f "$SWAP_FILE"
fi

# Create swap file
log "Creating swap file at $SWAP_FILE..."

if [ "$FS_TYPE" = "btrfs" ]; then
    # For btrfs, we need to:
    # 1. Create the file
    # 2. Disable CoW (should already be done on the subvolume, but let's be sure)
    # 3. Set permissions
    # 4. Allocate space

    log "Creating btrfs swap file..."
    truncate -s 0 "$SWAP_FILE"
    chattr +C "$SWAP_FILE" 2>/dev/null || log "Warning: Could not set nodatacow on swap file"
    fallocate -l "${SWAP_SIZE}M" "$SWAP_FILE" || dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$SWAP_SIZE" status=progress
else
    log "Creating regular swap file..."
    dd if=/dev/zero of="$SWAP_FILE" bs=1M count="$SWAP_SIZE" status=progress
fi

# Set correct permissions
chmod 600 "$SWAP_FILE"

# Format as swap
log "Formatting swap file..."
mkswap "$SWAP_FILE"

# Add to fstab if not already there
if ! grep -q "$SWAP_FILE" /etc/fstab; then
    log "Adding swap file to /etc/fstab..."
    echo "$SWAP_FILE none swap defaults 0 0" >> /etc/fstab
else
    log "Swap file already in /etc/fstab"
fi

# Activate swap
log "Activating swap..."
swapon "$SWAP_FILE"

log "Swap file setup complete!"
log "Swap status:"
swapon --show

exit 0
