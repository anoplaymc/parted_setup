#!/usr/bin/env bash

# Выходим при любой ошибке
set -e

# Проверяем, запущен ли скрипт от root
if [ "$EUID" -ne 0 ]; then
  echo "[-] Ошибка: Этот скрипт должен быть запущен от имени root."
  exit 1
fi

DISK="/dev/nvme0n1"
PART1="${DISK}p1"
PART2="${DISK}p2"

# Проверяем, существует ли такой диск в системе
if [ ! -b "$DISK" ]; then
  echo "[-] Ошибка: Диск $DISK не найден в системе!"
  exit 1
fi

echo "[+] Используем диск: $DISK"

read -p "[?] ВНИМАНИЕ! Все данные на диске $DISK будут уничтожены. Продолжить? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  echo "[-] Отменено пользователем."
  exit 1
fi

echo "[*] Создание таблицы разделов GPT..."
parted "$DISK" --script mklabel gpt

echo "[*] Создание EFI раздела (512MiB)..."
parted "$DISK" --script mkpart ESP fat32 1MiB 512MiB
parted "$DISK" --script set 1 boot on

echo "[*] Создание корневого раздела (ext4 на оставшееся место)..."
parted "$DISK" --script mkpart primary ext4 512MiB 100%

echo "[*] Форматирование EFI раздела в FAT32..."
mkfs.fat -F32 "$PART1"

echo "[*] Форматирование корневого раздела в EXT4..."
mkfs.ext4 -F "$PART2"

echo "[*] Монтирование файловых систем в /mnt..."
mount "$PART2" /mnt
mkdir -p /mnt/boot
mount "$PART1" /mnt/boot

echo "[+] Готово! Диск $DISK размечен и примонтирован в /mnt."
lsblk "$DISK"
