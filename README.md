# archinstall

Script for a minimal Arch Linux installation.

## Usage

**1. Connect to the internet**

The script assumes you are already connected to the internet. Ethernet should work out of the box. For Wi-Fi, connect using [iwctl](https://wiki.archlinux.org/title/Iwd#iwctl).

**2. Partition your disk**

Use [cfdisk](https://man.archlinux.org/man/cfdisk.8) or [fdisk](https://man.archlinux.org/man/fdisk.8). Recommended layout:

| Partition | Size | Type             |
| --------- | ---- | ---------------- |
| /dev/sda1 | 300M | EFI/BIOS boot    |
| /dev/sda2 | 8G   | Linux swap       |
| /dev/sda3 | rest | Linux filesystem |

**3. Edit the config**

Fill in your partition paths, timezone, locale, hostname, credentials, and any extra packages you want installed:

```
vim install.conf   # or your favourite text editor
```

**4. Run the script**

```
./install.sh
```

The script auto-detects BIOS or UEFI and handles the rest.

> [!WARNING]
> `install.conf` contains plaintext passwords. Delete it after installation.
