#!/bin/bash

# Variables
DISK="/dev/sda"
HOSTNAME="archbox"
USER1="colleague"
USER2="son"
PASSWORD="azerty123"
LUKS_PARTITION="/dev/sda2"
LUKS_MAPPER="cryptlvm"
VG_NAME="vg0"
LV_ROOT="lv_root"
LV_SWAP="lv_swap"
LV_HOME="lv_home"
LV_VIRTUALBOX="lv_virtualbox"
LV_SHARED="lv_shared"
LV_LUKS="lv_luks"
EFI_PARTITION="/dev/sda1"
ROOT_SIZE="40G"
SWAP_SIZE="2G"
HOME_SIZE="20G"
VIRTUALBOX_SIZE="10G"
SHARED_SIZE="5G"
LUKS_SIZE="10G"

# Configuration du clavier AZERTY
loadkeys fr

# Installation de l'environnement graphique
pacman -Sy --noconfirm xorg-server xorg-xinit

# Partitionnement du disque
parted -s $DISK mklabel gpt
parted -s $DISK mkpart primary fat32 1MiB 513MiB
parted -s $DISK set 1 esp on
parted -s $DISK mkpart primary ext4 513MiB 100%

# Chiffrement LUKS
echo -n "$PASSWORD" | cryptsetup luksFormat $LUKS_PARTITION -
echo -n "$PASSWORD" | cryptsetup open $LUKS_PARTITION $LUKS_MAPPER -

# Configuration LVM
pvcreate /dev/mapper/$LUKS_MAPPER
vgcreate $VG_NAME /dev/mapper/$LUKS_MAPPER
lvcreate -L $ROOT_SIZE -n $LV_ROOT $VG_NAME
lvcreate -L $SWAP_SIZE -n $LV_SWAP $VG_NAME
lvcreate -L $HOME_SIZE -n $LV_HOME $VG_NAME
lvcreate -L $VIRTUALBOX_SIZE -n $LV_VIRTUALBOX $VG_NAME
lvcreate -L $SHARED_SIZE -n $LV_SHARED $VG_NAME
lvcreate -L $LUKS_SIZE -n $LV_LUKS $VG_NAME

# Formatage des partitions
mkfs.fat -F32 $EFI_PARTITION
mkfs.ext4 /dev/$VG_NAME/$LV_ROOT
mkfs.ext4 /dev/$VG_NAME/$LV_HOME
mkfs.ext4 /dev/$VG_NAME/$LV_VIRTUALBOX
mkfs.ext4 /dev/$VG_NAME/$LV_SHARED
mkswap /dev/$VG_NAME/$LV_SWAP
swapon /dev/$VG_NAME/$LV_SWAP

# Montage des partitions
mount /dev/$VG_NAME/$LV_ROOT /mnt
mkdir -p /mnt/boot
mount $EFI_PARTITION /mnt/boot
mkdir -p /mnt/home
mount /dev/$VG_NAME/$LV_HOME /mnt/home
mkdir -p /mnt/virtualbox
mount /dev/$VG_NAME/$LV_VIRTUALBOX /mnt/virtualbox
mkdir -p /mnt/shared
mount /dev/$VG_NAME/$LV_SHARED /mnt/shared

# Installation d'Arch Linux
pacstrap /mnt base linux linux-firmware lvm2 vim networkmanager grub efibootmgr

# Génération du fichier fstab
genfstab -U /mnt >> /mnt/etc/fstab

# Configuration du système
arch-chroot /mnt <<EOF
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc
echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf
echo "KEYMAP=fr" > /etc/vconsole.conf
echo "$HOSTNAME" > /etc/hostname
echo "127.0.0.1 localhost" >> /etc/hosts
echo "::1       localhost" >> /etc/hosts
echo "127.0.1.1 $HOSTNAME.localdomain $HOSTNAME" >> /etc/hosts

# Configuration du bootloader
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Configuration des utilisateurs
useradd -m -G wheel -s /bin/bash $USER1
useradd -m -s /bin/bash $USER2
echo "$USER1:$PASSWORD" | chpasswd
echo "$USER2:$PASSWORD" | chpasswd
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Installation des outils supplémentaires
pacman -S --noconfirm virtualbox hyprland firefox gcc vim xfce4 lightdm lightdm-gtk-greeter

# Configuration de Hyprland
mkdir -p /home/$USER1/.config/hypr
echo "exec Hyprland" > /home/$USER1/.config/hypr/hyprland.conf

# Activation des services
systemctl enable NetworkManager
systemctl enable lightdm

# Configuration du volume chiffré LUKS
echo -n "$PASSWORD" | cryptsetup luksFormat /dev/$VG_NAME/$LV_LUKS -
echo -n "$PASSWORD" | cryptsetup open /dev/$VG_NAME/$LV_LUKS cryptluks -
mkfs.ext4 /dev/mapper/cryptluks
EOF

# Fin de l'installation
umount -R /mnt
swapoff -a
echo "Installation terminée ! Redémarrez la machine."
