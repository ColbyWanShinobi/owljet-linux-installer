# Btrfs Subvolume Configuration for Calamares

This installer has been configured to use **btrfs** as the default filesystem with a comprehensive subvolume layout and swap file support.

## Features

- **Separate /boot partition**: 2GB ext4 partition for kernels and initramfs
- **EFI System Partition**: 1GB for UEFI boot files
- **Default filesystem**: btrfs with zstd compression for root
- **Subvolume-based layout**: Organized subvolumes for better snapshots and management
- **Swap file**: Uses a swap file instead of a swap partition (btrfs-friendly)
- **Optimized mount options**: SSD detection with appropriate optimizations
- **CoW optimization**: nodatacow set for database and VM-related subvolumes

## Partition Layout

The installer creates the following partition scheme:

| Partition | Size | Filesystem | Mount Point | Purpose |
|-----------|------|------------|-------------|---------|
| EFI | 1GB | FAT32 | /boot/efi | UEFI boot files |
| Boot | 2GB | ext4 | /boot | Kernels and initramfs |
| Root | Rest | btrfs | / | Root filesystem with subvolumes |

## Subvolume Layout

The installer creates the following btrfs subvolume structure:

| Subvolume | Mount Point | Purpose | CoW |
|-----------|-------------|---------|-----|
| @ | / | Root filesystem | Yes |
| @home | /home | User home directories | Yes |
| @log | /var/log | System logs | No |
| @cache | /var/cache | Package cache | No |
| @libvirt | /var/lib/libvirt | Virtual machines | No |
| @flatpak | /var/lib/flatpak | Flatpak applications | Yes |
| @docker | /var/lib/docker | Docker containers | No |
| @containers | /var/lib/containers | Podman containers | No |
| @machines | /var/lib/machines | systemd-nspawn containers | No |
| @var_tmp | /var/tmp | Temporary files | No |
| @tmp | /tmp | Temporary files | No |
| @opt | /opt | Optional software | Yes |
| @swap | /swap | Swap file location | No |

## Mount Options

### Base Options (All Subvolumes)
- `defaults` - Default mount options
- `noatime` - Don't update access times (improves performance)
- `compress=zstd` - zstd compression (good balance of speed and compression ratio)
- `space_cache=v2` - Modern space cache version

### SSD-Specific Options (Auto-detected)
- `ssd` - SSD-specific optimizations
- `discard=async` - Asynchronous TRIM support

### No-CoW Subvolumes
Certain subvolumes have `nodatacow` enabled to prevent copy-on-write issues with:
- Databases (libvirt, docker, containers)
- Log files (log, cache, tmp)
- Virtual machine images

## Installation Flow

The installation process follows this sequence:

1. **partition** - Creates partitions (EFI 1GB + /boot 2GB ext4 + / btrfs)
2. **btrfs-subvolumes** - Creates all subvolumes on the btrfs filesystem
3. **mount** - Standard Calamares mount
4. **btrfs-remount** - Remounts with proper subvolume structure
5. *(standard installation steps)*
6. **swap-file** - Creates swap file in the @swap subvolume
7. **umount** - Cleanup

## Configuration Files

### New Files Created

1. **calamares/modules/partition.conf** - Partition module configuration
   - Sets btrfs as default filesystem
   - Defines subvolume layout
   - Configures swap file preference

2. **calamares/modules/btrfs-subvolumes.conf** - Subvolume creation module
   - Runs after partitioning
   - Creates all btrfs subvolumes
   - Sets nodatacow attributes

3. **calamares/modules/btrfs-remount.conf** - Remount module
   - Runs after standard mount
   - Mounts all subvolumes in correct order
   - Applies optimized mount options

4. **calamares/modules/swap-file.conf** - Swap file creation module
   - Runs near end of installation
   - Creates appropriately-sized swap file
   - Adds swap file to /etc/fstab

5. **calamares/scripts/create-btrfs-subvolumes.sh** - Subvolume creation script
   - Creates all subvolumes on the btrfs root
   - Sets nodatacow attributes where needed
   - Handles errors gracefully

6. **calamares/scripts/remount-btrfs.sh** - Remount script
   - Remounts root with @ subvolume
   - Mounts all other subvolumes
   - Detects SSD for optimizations

7. **calamares/scripts/create-swap-file.sh** - Swap file creation script
   - Calculates swap size based on RAM
   - Creates btrfs-compatible swap file
   - Updates /etc/fstab

### Modified Files

1. **calamares/settings.conf** - Main configuration
   - Added btrfs-subvolumes to execution sequence
   - Added btrfs-remount after mount
   - Added swap-file before umount

2. **calamares/modules/fstab.conf** - Filesystem table configuration
   - Updated with btrfs-specific mount options
   - Added subvolume-specific options
   - Configured swap file paths

## Swap File Sizing

The swap file size is automatically calculated based on system RAM:

- **RAM ≤ 2GB**: Swap = 2 × RAM
- **2GB < RAM ≤ 8GB**: Swap = RAM
- **RAM > 8GB**: Swap = 8GB (allows hibernation)

## Benefits of This Layout

1. **Separate /boot Partition**:
   - Keeps boot files on reliable ext4 filesystem
   - Prevents boot issues if btrfs has problems
   - Standard 2GB size accommodates multiple kernel versions
   - Compatible with all bootloaders

2. **Snapshot Flexibility**: Separate subvolumes allow selective snapshots
   - Snapshot system (@) without user data (@home)
   - Exclude logs and cache from snapshots
   - Easy rollback of system changes
   - /boot not affected by btrfs snapshots

3. **Performance**:
   - nodatacow for write-heavy directories (logs, databases)
   - Compression for space savings
   - SSD optimizations when applicable
   - ext4 for /boot provides fast, reliable boot

4. **Maintenance**:
   - Easier to manage disk quotas per subvolume
   - Can have different backup policies per subvolume
   - Isolation of different data types
   - Simple ext4 boot partition for recovery

5. **Container/VM Support**:
   - Optimized for Docker, Podman, libvirt
   - Prevents performance issues with CoW on VMs
   - Separate subvolumes for different container runtimes

## Post-Installation

After installation, you can:

1. **Create snapshots**:
   ```bash
   sudo btrfs subvolume snapshot / /.snapshots/root-$(date +%Y%m%d)
   ```

2. **List subvolumes**:
   ```bash
   sudo btrfs subvolume list /
   ```

3. **Check compression**:
   ```bash
   sudo compsize /
   ```

4. **Monitor swap**:
   ```bash
   swapon --show
   free -h
   ```

## Troubleshooting

### Swap File Issues
If the swap file isn't working:
```bash
sudo swapon -a
sudo systemctl daemon-reload
```

### Checking Subvolume Mounts
```bash
findmnt -t btrfs
```

### Verifying nodatacow Attribute
```bash
lsattr /var/log
# Should show 'C' flag
```

## Notes

- All scripts are located in `/etc/calamares/scripts/`
- Module configurations are in `/etc/calamares/modules/`
- Scripts log to stdout/stderr (visible in Calamares log)
- All operations are designed to be idempotent where possible

## References

- Btrfs Wiki: https://btrfs.wiki.kernel.org/
- Calamares Documentation: https://calamares.io/
- Debian Btrfs Wiki: https://wiki.debian.org/Btrfs
