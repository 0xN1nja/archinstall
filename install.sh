#!/usr/bin/env bash

set -euo pipefail

CONFIG_FILE="${1:-./install.conf}"
[[ -f "$CONFIG_FILE" ]] || {
	echo "Config file not found: $CONFIG_FILE"
	exit 1
}
source "$CONFIG_FILE"

for var in BOOT_PART SWAP_PART ROOT_PART TIMEZONE LOCALE KEYMAP HOSTNAME USERNAME USER_PASSWORD ROOT_PASSWORD; do
	[[ -n "${!var:-}" ]] || {
		echo "Missing config value: $var"
		exit 1
	}
done

[[ $EUID -eq 0 ]] || {
	echo "Run as root."
	exit 1
}

[[ -d /sys/firmware/efi ]] && BOOT_MODE="uefi" || BOOT_MODE="bios"

loadkeys "$KEYMAP"
timedatectl set-ntp true

for part_var in BOOT_PART SWAP_PART ROOT_PART; do
	part="${!part_var}"
	[[ -b "$part" ]] || {
		echo "Partition not found: $part"
		exit 1
	}
done

mkfs.fat -F 32 "$BOOT_PART"
mkswap "$SWAP_PART"
swapon "$SWAP_PART"
mkfs.ext4 "$ROOT_PART"

mount "$ROOT_PART" /mnt

if [[ "$BOOT_MODE" == "uefi" ]]; then
	mkdir -p /mnt/boot/efi
	mount "$BOOT_PART" /mnt/boot/efi
else
	mkdir -p /mnt/boot
	mount "$BOOT_PART" /mnt/boot
fi

pacstrap /mnt base linux linux-firmware grub efibootmgr networkmanager sudo git vim ${EXTRA_PACKAGES:-}
genfstab -U /mnt >>/mnt/etc/fstab

DISK="${ROOT_PART%[0-9]}"

printf '%s\n' '#!/usr/bin/env bash' 'set -euo pipefail' \
	"ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime" \
	'hwclock --systohc' \
	"sed -i 's/^#$LOCALE/$LOCALE/' /etc/locale.gen" \
	'locale-gen' \
	"echo 'LANG=$LOCALE' > /etc/locale.conf" \
	"echo 'KEYMAP=$KEYMAP' > /etc/vconsole.conf" \
	"echo '$HOSTNAME' > /etc/hostname" \
	"printf '127.0.0.1\tlocalhost\n::1\t\tlocalhost\n127.0.1.1\t$HOSTNAME.localdomain $HOSTNAME\n' > /etc/hosts" \
	"echo 'root:$ROOT_PASSWORD' | chpasswd" \
	"useradd -m -G wheel -s /bin/bash '$USERNAME'" \
	"echo '$USERNAME:$USER_PASSWORD' | chpasswd" \
	"sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers" \
	>/mnt/root/chroot_setup.sh

if [[ "$BOOT_MODE" == "uefi" ]]; then
	echo "grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB $DISK" >>/mnt/root/chroot_setup.sh
else
	echo "grub-install --target=i386-pc $DISK" >>/mnt/root/chroot_setup.sh
fi

printf '%s\n' \
	'grub-mkconfig -o /boot/grub/grub.cfg' \
	'systemctl enable NetworkManager' \
	>>/mnt/root/chroot_setup.sh

chmod +x /mnt/root/chroot_setup.sh
arch-chroot /mnt /root/chroot_setup.sh
rm /mnt/root/chroot_setup.sh

umount -R /mnt
reboot
