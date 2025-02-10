#!/bin/bash
set -e

############################################
# Variables
############################################
DISK="/dev/sda"
HOSTNAME="archbox"
USER1="colleague"
USER2="son"
PASSWORD="azerty123"

EFI_PARTITION="${DISK}1"
LUKS_PARTITION="${DISK}2"
LUKS_MAPPER="cryptlvm"
VG_NAME="vg0"

# Noms des volumes logiques
LV_ROOT="lv_root"
LV_SWAP="lv_swap"
LV_HOME="lv_home"
LV_VIRTUALBOX="lv_virtualbox"
LV_SHARED="lv_shared"
LV_LUKS="lv_luks"

# Tailles (adaptées pour un disque de 80Go)
ROOT_SIZE="30G"
SWAP_SIZE="2G"
HOME_SIZE="15G"
VIRTUALBOX_SIZE="10G"
SHARED_SIZE="5G"
LUKS_SIZE="10G"

############################################
# Préparation et partitionnement
############################################

# Configuration du clavier
loadkeys fr

# Active la synchronisation de l’horloge
timedatectl set-ntp true

# Installation temporaire de Xorg (pour répondre à la demande de l’installateur)
pacman -Sy --noconfirm xorg-server xorg-xinit

# Partitionnement avec parted
parted -s $DISK mklabel gpt
# Partition EFI : de 1MiB à 513MiB
parted -s $DISK mkpart primary fat32 1MiB 513MiB
parted -s $DISK set 1 esp on
# Partition pour le conteneur LUKS (et donc LVM) : de 513MiB jusqu’à la fin
parted -s $DISK mkpart primary ext4 513MiB 100%

############################################
# Mise en place du chiffrement et de LVM
############################################

# Chiffrement de la partition LUKS
echo -n "$PASSWORD" | cryptsetup -q luksFormat $LUKS_PARTITION --key-file -
echo -n "$PASSWORD" | cryptsetup open $LUKS_PARTITION $LUKS_MAPPER --key-file -

# Création du volume physique et du groupe LVM sur le container déchiffré
pvcreate /dev/mapper/$LUKS_MAPPER
vgcreate $VG_NAME /dev/mapper/$LUKS_MAPPER

# Création des volumes logiques
lvcreate -L $ROOT_SIZE      -n $LV_ROOT       $VG_NAME
lvcreate -L $SWAP_SIZE      -n $LV_SWAP       $VG_NAME
lvcreate -L $HOME_SIZE      -n $LV_HOME       $VG_NAME
lvcreate -L $VIRTUALBOX_SIZE -n $LV_VIRTUALBOX $VG_NAME
lvcreate -L $SHARED_SIZE    -n $LV_SHARED     $VG_NAME
lvcreate -L $LUKS_SIZE      -n $LV_LUKS       $VG_NAME

############################################
# Formatage et montage
############################################

# Formatage de la partition EFI
mkfs.fat -F32 $EFI_PARTITION

# Formatage des volumes logiques
mkfs.ext4 /dev/$VG_NAME/$LV_ROOT
mkfs.ext4 /dev/$VG_NAME/$LV_HOME
mkfs.ext4 /dev/$VG_NAME/$LV_VIRTUALBOX
mkfs.ext4 /dev/$VG_NAME/$LV_SHARED
mkswap /dev/$VG_NAME/$LV_SWAP
swapon /dev/$VG_NAME/$LV_SWAP

# Montage des partitions dans /mnt
mount /dev/$VG_NAME/$LV_ROOT /mnt
mkdir -p /mnt/boot
mount $EFI_PARTITION /mnt/boot
mkdir -p /mnt/home
mount /dev/$VG_NAME/$LV_HOME /mnt/home
mkdir -p /mnt/virtualbox
mount /dev/$VG_NAME/$LV_VIRTUALBOX /mnt/virtualbox
mkdir -p /mnt/shared
mount /dev/$VG_NAME/$LV_SHARED /mnt/shared

############################################
# Installation de base avec pacstrap
############################################

pacstrap /mnt base linux linux-firmware lvm2 cryptsetup vim networkmanager grub efibootmgr

# Génération du fichier fstab
genfstab -U /mnt >> /mnt/etc/fstab

############################################
# Configuration système dans le chroot
############################################

arch-chroot /mnt /bin/bash <<'EOF'
set -e

# Fuseau horaire et horloge
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc

# Localisation
echo "fr_FR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=fr_FR.UTF-8" > /etc/locale.conf
echo "KEYMAP=fr" > /etc/vconsole.conf

# Nom de la machine et configuration réseau
echo "archbox" > /etc/hostname
cat <<HOSTS_EOF >> /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   archbox.localdomain archbox
HOSTS_EOF

# Mise à jour de mkinitcpio pour inclure encrypt et lvm2
sed -i 's/^HOOKS=.*/HOOKS=(base udev autodetect modconf block encrypt lvm2 filesystems keyboard fsck)/' /etc/mkinitcpio.conf
mkinitcpio -P

# Configuration de GRUB avec le paramètre cryptdevice
UUID=\$(blkid -s UUID -o value /dev/sda2)
sed -i 's/^GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="cryptdevice=UUID=\$UUID:cryptlvm"/' /etc/default/grub
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# Création des comptes utilisateurs
useradd -m -G wheel -s /bin/bash colleague
useradd -m -s /bin/bash son
echo "colleague:azerty123" | chpasswd
echo "son:azerty123" | chpasswd

# Autorisation pour le groupe wheel
echo "%wheel ALL=(ALL) ALL" >> /etc/sudoers

# Installation d'outils complémentaires
pacman -Sy --noconfirm virtualbox hyprland firefox gcc vim

# Configuration personnalisée de Hyprland pour l'utilisateur colleague
mkdir -p /home/colleague/.config/hypr
echo "exec Hyprland" > /home/colleague/.config/hypr/hyprland.conf
chown -R colleague:colleague /home/colleague/.config

# Activation des services système
systemctl enable NetworkManager
systemctl enable vboxservice

# Configuration d’un volume logique supplémentaire chiffré (10Go) destiné à être monté manuellement
echo -n "azerty123" | cryptsetup -q luksFormat /dev/vg0/lv_luks --key-file -
echo -n "azerty123" | cryptsetup open /dev/vg0/lv_luks cryptluks --key-file -
mkfs.ext4 /dev/mapper/cryptluks
echo "cryptluks /dev/vg0/lv_luks none luks" >> /etc/crypttab

# Correction du montage du dossier partagé : dans le système installé, il apparaît en /shared
# (car /mnt devient la racine une fois chrooté)
chown -R colleague:colleague /shared
chown -R son:son /shared
chmod 770 /shared

EOF

############################################
# Fin de l'installation
############################################

umount -R /mnt
swapoff -a

echo "Installation terminée ! Redémarrez la machine."
