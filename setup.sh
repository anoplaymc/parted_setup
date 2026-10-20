#!/usr/bin/env bash

# Exit immediately if any command fails
set -e

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "[-] Error: This script must be run as root."
  exit 1
fi

echo "[*] Available disks on your system:"
lsblk -d -o NAME,SIZE,MODEL,TYPE | grep -E 'disk|NAME'

echo ""
read -p "What disk do you want to install on? examples: nvme0n1 sda vda [ ]: " USER_DISK

# Validate user input
if [ -z "$USER_DISK" ]; then
  echo "[-] Disk not found or it is a flash drive"
  exit 1
fi

DISK="/dev/$USER_DISK"

# Check if the block device exists
if [ ! -b "$DISK" ]; then
  echo "[-] Disk not found or it is a flash drive"
  exit 1
fi

# Determine partition suffixes (e.g., nvme0n1p1 vs sda1)
if [[ "$DISK" =~ nvme[0-9]+n[0-9]+ ]]; then
  PART1="${DISK}p1"
  PART2="${DISK}p2"
else
  PART1="${DISK}1"
  PART2="${DISK}2"
fi

echo "[+] Selected disk: $DISK"

read -p "[?] WARNING! All data on $DISK will be destroyed. Do you want to continue? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "[-] Cancelled by user."
  exit 1
fi

echo "[*] Creating GPT partition table..."
parted "$DISK" --script mklabel gpt

echo "[*] Creating EFI partition (512MiB)..."
parted "$DISK" --script mkpart ESP fat32 1MiB 512MiB
parted "$DISK" --script set 1 boot on

echo "[*] Creating root partition (ext4 using remaining space)..."
parted "$DISK" --script mkpart primary ext4 512MiB 100%

echo "[*] Formatting EFI partition as FAT32..."
mkfs.fat -F32 "$PART1"

echo "[*] Formatting root partition as EXT4..."
mkfs.ext4 -F "$PART2"

echo "[*] Mounting filesystems to /mnt..."
mount "$PART2" /mnt
mkdir -p /mnt/boot
mount "$PART1" /mnt/boot

echo "[+] Done! $DISK has been successfully partitioned and mounted to /mnt."
lsblk "$DISK"
