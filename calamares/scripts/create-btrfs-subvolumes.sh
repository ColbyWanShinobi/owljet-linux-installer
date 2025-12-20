#!/bin/bash
# Script to create btrfs subvolumes for Calamares installation
# This script should be called after partitioning but before mounting

set -e

# Function to log messages
log() {
    echo "[btrfs-subvolumes] $1"
}

# Get the root partition from Calamares global storage
# The root partition device is passed as first argument
ROOT_DEVICE="$1"

if [ -z "$ROOT_DEVICE" ]; then
    log "ERROR: No root device specified"
    exit 1
fi

log "Creating btrfs subvolumes on $ROOT_DEVICE"

# Create a temporary mount point
MOUNT_POINT="/tmp/calamares-btrfs-$$"
mkdir -p "$MOUNT_POINT"

# Mount the btrfs root filesystem (top-level, subvolid=5)
log "Mounting btrfs root at $MOUNT_POINT"
mount -t btrfs -o subvolid=5 "$ROOT_DEVICE" "$MOUNT_POINT"

# Create all required subvolumes
log "Creating subvolumes..."

# Root subvolume
btrfs subvolume create "$MOUNT_POINT/@" || log "Warning: @ subvolume might already exist"

# Home subvolume
btrfs subvolume create "$MOUNT_POINT/@home" || log "Warning: @home subvolume might already exist"

# Var log subvolume
btrfs subvolume create "$MOUNT_POINT/@log" || log "Warning: @log subvolume might already exist"

# Var cache subvolume
btrfs subvolume create "$MOUNT_POINT/@cache" || log "Warning: @cache subvolume might already exist"

# Libvirt subvolume
btrfs subvolume create "$MOUNT_POINT/@libvirt" || log "Warning: @libvirt subvolume might already exist"

# Flatpak subvolume
btrfs subvolume create "$MOUNT_POINT/@flatpak" || log "Warning: @flatpak subvolume might already exist"

# Docker subvolume
btrfs subvolume create "$MOUNT_POINT/@docker" || log "Warning: @docker subvolume might already exist"

# Containers subvolume
btrfs subvolume create "$MOUNT_POINT/@containers" || log "Warning: @containers subvolume might already exist"

# Machines subvolume
btrfs subvolume create "$MOUNT_POINT/@machines" || log "Warning: @machines subvolume might already exist"

# Var tmp subvolume
btrfs subvolume create "$MOUNT_POINT/@var_tmp" || log "Warning: @var_tmp subvolume might already exist"

# Tmp subvolume
btrfs subvolume create "$MOUNT_POINT/@tmp" || log "Warning: @tmp subvolume might already exist"

# Opt subvolume
btrfs subvolume create "$MOUNT_POINT/@opt" || log "Warning: @opt subvolume might already exist"

# Swap subvolume (for swap file)
btrfs subvolume create "$MOUNT_POINT/@swap" || log "Warning: @swap subvolume might already exist"

# Set nodatacow attribute for subvolumes that should not use CoW
# This is important for databases, VMs, and swap files
log "Setting nodatacow attribute for appropriate subvolumes..."
chattr +C "$MOUNT_POINT/@log" 2>/dev/null || log "Warning: Could not set nodatacow on @log"
chattr +C "$MOUNT_POINT/@cache" 2>/dev/null || log "Warning: Could not set nodatacow on @cache"
chattr +C "$MOUNT_POINT/@libvirt" 2>/dev/null || log "Warning: Could not set nodatacow on @libvirt"
chattr +C "$MOUNT_POINT/@docker" 2>/dev/null || log "Warning: Could not set nodatacow on @docker"
chattr +C "$MOUNT_POINT/@containers" 2>/dev/null || log "Warning: Could not set nodatacow on @containers"
chattr +C "$MOUNT_POINT/@machines" 2>/dev/null || log "Warning: Could not set nodatacow on @machines"
chattr +C "$MOUNT_POINT/@var_tmp" 2>/dev/null || log "Warning: Could not set nodatacow on @var_tmp"
chattr +C "$MOUNT_POINT/@tmp" 2>/dev/null || log "Warning: Could not set nodatacow on @tmp"
chattr +C "$MOUNT_POINT/@swap" 2>/dev/null || log "Warning: Could not set nodatacow on @swap"

# List all subvolumes
log "Subvolumes created:"
btrfs subvolume list "$MOUNT_POINT"

# Unmount the top-level subvolume
log "Unmounting $MOUNT_POINT"
umount "$MOUNT_POINT"
rmdir "$MOUNT_POINT"

log "Btrfs subvolumes created successfully"
exit 0
