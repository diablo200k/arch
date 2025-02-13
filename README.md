# Installation Automatisée d'Arch Linux avec Chiffrement et LVM

Ce script automatise l'installation d'Arch Linux en respectant les consignes du projet, notamment :
- **Sécurité** : Chiffrement complet (LUKS + LVM).
- **Organisation de l'espace** : Partitionnement en plusieurs volumes logiques (système, swap, home, VirtualBox, dossier partagé, volume chiffré manuel).
- **Configuration** : Installation des logiciels et paramètres adaptés aux besoins de l'utilisateur (colleague) et de son fils.
- **Compatibilité** : Système installé en mode UEFI et configuré en français.

---

## 1. Définition des Variables et Préparation

### Variables
- **Disque cible** : `/dev/sda`
- **Utilisateurs** : `colleague` et `son`
- **Mot de passe par défaut** : `azerty123`

*Pourquoi ?*  
Centraliser ces informations permet de modifier facilement les paramètres sans devoir parcourir tout le script.

### Préparation de l’Environnement
- **Configuration du clavier** :  
  `loadkeys fr` (pour un clavier en français)
- **Synchronisation de l’horloge** :  
  `timedatectl set-ntp true`  
  (mise à jour du trousseau de clés incluse)

*Pourquoi ?*  
Ces étapes garantissent un environnement d’installation correctement configuré pour un usage en français et une horloge synchronisée.

---

## 2. Partitionnement du Disque et Configuration du Chiffrement

### Création des Partitions
- Le disque est formaté en **GPT** pour fonctionner en mode UEFI.
- **Partition EFI** : Créée et formatée en **FAT32** (indispensable pour le démarrage en UEFI).
- **Partition principale** : Créée pour contenir le reste du système et destinée à être chiffrée.

### Chiffrement et LVM
- **Chiffrement** :  
  La partition principale est chiffrée avec **LUKS** pour sécuriser les données.
- **Configuration LVM** :  
  Après déchiffrement, création de plusieurs volumes logiques :
  - `lv_root` (30 Go) : Pour le système.
  - `lv_swap` (2 Go) : Pour la swap.
  - `lv_home` (15 Go) : Pour les fichiers personnels.
  - `lv_virtualbox` (10 Go) : Pour la virtualisation.
  - `lv_shared` (5 Go) : Pour le dossier partagé entre colleague et son.
  - `lv_luks` (10 Go) : Pour un espace chiffré à monter manuellement.

*Pourquoi ?*  
Le chiffrement protège l'ensemble du disque, tandis que LVM permet une organisation flexible de l'espace pour répondre aux exigences du projet.

---

## 3. Formatage et Montage des Partitions

### Formatage
- **Partition EFI** : Formatée en **FAT32**.
- **Volumes logiques** (`root`, `home`, `virtualbox`, `shared`) : Formatés en **ext4**.
- **Swap** : Préparée et activée.

### Montage
- Le système de fichiers racine est monté sur `/mnt`.
- La partition EFI est montée sur `/mnt/boot`.
- Les autres volumes logiques sont montés dans des dossiers dédiés :
  - `/mnt/home`
  - `/mnt/virtualbox`
  - `/mnt/shared`

*Pourquoi ?*  
Le formatage et le montage préparent le disque pour l'installation du système et garantissent l'utilisation correcte de chaque espace.

---

## 4. Installation du Système de Base et Configuration Initiale

### Installation de Base
Utilisation de la commande `pacstrap` pour installer :
- Le kernel et le firmware.
- Les outils pour LVM et **cryptsetup**.
- **GRUB** et d'autres utilitaires essentiels.

### Génération de l’fstab
Le fichier `/etc/fstab` est automatiquement généré pour définir les volumes à monter au démarrage.

### Configuration en Chroot
Dans l'environnement **chroot**, les configurations suivantes sont effectuées :
- **Fuseau horaire, date et langue** : Paramétrage pour un usage en français.
- **Nom de la machine** et configuration du fichier `/etc/hosts`.
- **Hooks** : Ajout de `encrypt` et `lvm2` dans `mkinitcpio.conf` pour supporter le démarrage avec disque chiffré.
- **Installation de GRUB** en mode UEFI avec le paramètre `cryptdevice` pour permettre le déchiffrement au démarrage.

*Pourquoi ?*  
Ces réglages garantissent que le système démarre correctement, gère le chiffrement et respecte les paramètres régionaux.

---

## 5. Création des Utilisateurs et Installation des Logiciels

### Création des Utilisateurs
- **colleague** : Avec droits sudo (membre du groupe `wheel`).
- **son** : Compte utilisateur simple.

*Mot de passe pour les deux* : `azerty123`

### Installation des Logiciels
Les logiciels suivants sont installés :
- **VirtualBox** : Pour la virtualisation.
- **Hyprland** : Avec une configuration basique pour `colleague`.
- **Firefox**
- **gcc**
- **vim**

*Pourquoi ?*  
Ces logiciels répondent aux besoins en virtualisation, navigation internet, et développement en C, et permettent de gérer efficacement le système.

---

## 6. Configuration des Volumes Spécifiques et Finalisation

### Volume Chiffré Supplémentaire
- Le volume logique `lv_luks` est de nouveau chiffré et formaté.
- Une entrée est ajoutée dans `/etc/crypttab` pour permettre un montage manuel après démarrage.

### Dossier Partagé
- Le volume `lv_shared` est configuré pour être accessible par `colleague` et `son` via un ajustement des permissions (`chown` et `chmod`).

### Finalisation
- Tous les volumes sont démontés et la swap est désactivée.
- Un message final indique que l'installation est terminée et invite à redémarrer.

*Pourquoi ?*  
Ces étapes garantissent que tous les volumes sont correctement configurés et que l'installation se termine de manière propre, avec sécurité et respect des consignes du projet.

---

## Conclusion

En résumé, ce script permet de réaliser une installation automatisée d'Arch Linux avec :
- Un **chiffrement complet** (LUKS + LVM) pour la sécurité.
- Une **organisation optimisée** de l'espace disque via des volumes logiques adaptés.
- Une **installation des logiciels** et des configurations répondant aux besoins de l'utilisateur et de son fils.
- Une installation en mode **UEFI** et une configuration en français.

Utilisez ce script pour une installation rapide, sécurisée et parfaitement adaptée à un environnement nécessitant une gestion fine des volumes et une protection accrue des données.
