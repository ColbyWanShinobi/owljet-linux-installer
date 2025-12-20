#!/bin/bash
# Script to mount btrfs subvolumes in the correct order
# This script is called by the mount module

set -e

# Function to log messages
log() {
    echo "[mount-btrfs] $1"
}

# Get parameters
ROOT_DEVICE="$1"
TARGET_DIR="$2"

if [ -z "$ROOT_DEVICE" ] || [ -z "$TARGET_DIR" ]; then
    log "ERROR: Usage: $0 <root_device> <target_dir>"
    exit 1
fi

# Check if this is a btrfs filesystem
FS_TYPE=$(lsblk -no FSTYPE "$ROOT_DEVICE" 2>/dev/null || echo "")
if [ "$FS_TYPE" != "btrfs" ]; then
    log "Root filesystem is not btrfs, skipping..."
    exit 0
fi

log "Mounting btrfs subvolumes for $ROOT_DEVICE at $TARGET_DIR"

# Base mount options for btrfs
BTRFS_OPTS="defaults,noatime,compress=zstd,space_cache=v2"

# Check if SSD
if [ -f /sys/block/$(basename "$ROOT_DEVICE" | sed 's/[0-9]*$//')/queue/rotational ]; then
    ROTATIONAL=$(cat /sys/block/$(basename "$ROOT_DEVICE" | sed 's/[0-9]*$//')/queue/rotational)
    if [ "$ROTATIONAL" = "0" ]; then
        BTRFS_OPTS="${BTRFS_OPTS},ssd,discard=async"
        log "SSD detected, adding SSD-specific options"
    fi
fi

# Mount root subvolume first
log "Mounting @ subvolume to $TARGET_DIR"
mount -t btrfs -o "subvol=@,${BTRFS_OPTS}" "$ROOT_DEVICE" "$TARGET_DIR"

# Create mount points and mount other subvolumes
declare -A SUBVOLS=(
    ["@home"]="/home"
    ["@log"]="/var/log"
    ["@cache"]="/var/cache"
    ["@libvirt"]="/var/lib/libvirt"
    ["@flatpak"]="/var/lib/flatpak"
    ["@docker"]="/var/lib/docker"
    ["@containers"]="/var/lib/containers"
    ["@machines"]="/var/lib/machines"
    ["@var_tmp"]="/var/tmp"
    ["@tmp"]="/tmp"
    ["@opt"]="/opt"
    ["@swap"]="/swap"
)

for subvol in "${!SUBVOLS[@]}"; do
    mountpoint="${SUBVOLS[$subvol]}"
    full_path="${TARGET_DIR}${mountpoint}"

    # Create mount point if it doesn't exist
    if [ ! -d "$full_path" ]; then
        log "Creating directory $full_path"
        mkdir -p "$full_path"
    fi

    # Determine mount options (some subvolumes need nodatacow)
    SUBVOL_OPTS="subvol=${subvol},${BTRFS_OPTS}"
    case "$subvol" in
        @log|@cache|@libvirt|@docker|@containers|@machines|@var_tmp|@tmp|@swap)
            SUBVOL_OPTS="subvol=${subvol},${BTRFS_OPTS},nodatacow"
            ;;
    esac

    log "Mounting $subvol to $mountpoint"
    mount -t btrfs -o "$SUBVOL_OPTS" "$ROOT_DEVICE" "$full_path"
done

log "All btrfs subvolumes mounted successfully"
exit 0
