#!/bin/bash

# Script to backup /etc/calamares and replace it with local calamares configuration
# Usage: sudo ./install-calamares-config.sh

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}Error: This script must be run as root (use sudo)${NC}"
   exit 1
fi

# Get the directory where the script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
SOURCE_DIR="${SCRIPT_DIR}/calamares"
TARGET_DIR="/etc/calamares"
BACKUP_DIR="${SCRIPT_DIR}/backups"

# Check if source calamares folder exists
if [ ! -d "$SOURCE_DIR" ]; then
    echo -e "${RED}Error: Source calamares folder not found at: $SOURCE_DIR${NC}"
    exit 1
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Generate timestamp
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="${BACKUP_DIR}/calamares_backup_${TIMESTAMP}.tar.gz"

# Backup existing /etc/calamares if it exists
if [ -d "$TARGET_DIR" ]; then
    echo -e "${YELLOW}Backing up existing /etc/calamares...${NC}"
    tar -czf "$BACKUP_FILE" -C /etc calamares
    echo -e "${GREEN}Backup created: $BACKUP_FILE${NC}"

    # Remove existing /etc/calamares
    echo -e "${YELLOW}Removing existing /etc/calamares...${NC}"
    rm -rf "$TARGET_DIR"
else
    echo -e "${YELLOW}No existing /etc/calamares found, skipping backup${NC}"
fi

# Copy new calamares configuration
echo -e "${YELLOW}Installing new calamares configuration...${NC}"
cp -r "$SOURCE_DIR" "$TARGET_DIR"

# Set proper permissions
echo -e "${YELLOW}Setting permissions...${NC}"
chown -R root:root "$TARGET_DIR"
chmod -R 755 "$TARGET_DIR"
find "$TARGET_DIR" -type f -exec chmod 644 {} \;

echo -e "${GREEN}✓ Calamares configuration installed successfully!${NC}"
echo -e "${GREEN}✓ Backup saved to: $BACKUP_FILE${NC}"
