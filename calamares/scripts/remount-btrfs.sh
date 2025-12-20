#!/bin/bash
# Script to remount btrfs with subvolumes
# This runs after Calamares has mounted the root partition

set -e

log() {
    echo "[btrfs-remount] $1"
}

# Find the Calamares root mount point
# Typically /tmp/calamares-root or similar
for possible_root in /tmp/calamares-root-* /tmp/calamares-root; do
    if mountpoint -q "$possible_root" 2>/dev/null; then
        TARGET="$possible_root"
        break
    fi
done

if [ -z "$TARGET" ]; then
    log "ERROR: Could not find Calamares target mount point"
    log "Trying to find any btrfs mount under /tmp..."
    TARGET=$(mount | grep "type btrfs" | grep "/tmp/" | head -1 | awk '{print $3}')
    if [ -z "$TARGET" ]; then
        log "ERROR: No btrfs filesystem mounted in /tmp"
        exit 0
    fi
fi

log "Found target mount at: $TARGET"

# Get the device that's mounted there
ROOT_DEVICE=$(findmnt -n -o SOURCE "$TARGET")
log "Root device: $ROOT_DEVICE"

# Check if it's btrfs
FS_TYPE=$(lsblk -no FSTYPE "$ROOT_DEVICE" 2>/dev/null || echo "")
if [ "$FS_TYPE" != "btrfs" ]; then
    log "Filesystem is not btrfs ($FS_TYPE), nothing to do"
    exit 0
fi

log "Detected btrfs filesystem, remounting with subvolumes..."

# Determine mount options
OPTS="defaults,noatime,compress=zstd,space_cache=v2"
DEV_NAME=$(basename "$ROOT_DEVICE" | sed 's/[0-9]*$//')
if [ -f "/sys/block/$DEV_NAME/queue/rotational" ]; then
    ROTATIONAL=$(cat "/sys/block/$DEV_NAME/queue/rotational" 2>/dev/null || echo "1")
    if [ "$ROTATIONAL" = "0" ]; then
        OPTS="$OPTS,ssd,discard=async"
        log "SSD detected"
    fi
fi

# Unmount everything under TARGET first
log "Unmounting current mounts..."
for mount in $(mount | grep "$TARGET" | awk '{print $3}' | sort -r); do
    log "Unmounting $mount"
    umount "$mount" 2>/dev/null || true
done

# Mount @ subvolume as root
log "Mounting @ subvolume to $TARGET"
mount -t btrfs -o "subvol=@,$OPTS" "$ROOT_DEVICE" "$TARGET" || {
    log "ERROR: Failed to mount @ subvolume"
    log "Falling back to standard mount..."
    mount -t btrfs "$ROOT_DEVICE" "$TARGET"
    exit 0
}

# Create directories and mount subvolumes
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

for subvol in "@home" "@log" "@cache" "@libvirt" "@flatpak" "@docker" "@containers" "@machines" "@var_tmp" "@tmp" "@opt" "@swap"; do
    case "$subvol" in
        "@home") mp="/home" ;;
        "@log") mp="/var/log" ;;
        "@cache") mp="/var/cache" ;;
        "@libvirt") mp="/var/lib/libvirt" ;;
        "@flatpak") mp="/var/lib/flatpak" ;;
        "@docker") mp="/var/lib/docker" ;;
        "@containers") mp="/var/lib/containers" ;;
        "@machines") mp="/var/lib/machines" ;;
        "@var_tmp") mp="/var/tmp" ;;
        "@tmp") mp="/tmp" ;;
        "@opt") mp="/opt" ;;
        "@swap") mp="/swap" ;;
        *) continue ;;
    esac

    full_path="$TARGET$mp"
    mkdir -p "$full_path"

    # Determine options
    case "$subvol" in
        "@log"|"@cache"|"@libvirt"|"@docker"|"@containers"|"@machines"|"@var_tmp"|"@tmp"|"@swap")
            subvol_opts="subvol=$subvol,$OPTS,nodatacow"
            ;;
        *)
            subvol_opts="subvol=$subvol,$OPTS"
            ;;
    esac

    log "Mounting $subvol to $mp"
    mount -t btrfs -o "$subvol_opts" "$ROOT_DEVICE" "$full_path" || {
        log "WARNING: Failed to mount $subvol"
    }
done

log "Btrfs remount complete"
log "Current mounts:"
mount | grep "$TARGET"

exit 0
