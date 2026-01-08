# Docker Volume Backup & Restore

Scripts Bash permettant la **sauvegarde** et la **restauration fiable de volumes Docker**, avec gestion des containers, rotation des logs, politique de rétention et mode *hot backup*.

Conçu pour des **environnements Docker en production** sur serveurs Linux.

---

## Fonctionnalités

### Sauvegarde (`backup_volumes.sh`)
- Sauvegarde de tous les volumes Docker ou de volumes ciblés
- Arrêt automatique des containers utilisant le volume
- Mode **HOT BACKUP** (sans arrêt des containers)
- Exclusion de volumes via fichier dédié
- Rotation automatique des logs
- Rétention configurable des backups
- Logs détaillés et horodatés
- Vérification de l’existence et de l’intégrité des volumes

### Restauration (`restore_volume.sh`)
- Restauration exacte depuis un backup `.tar.gz`
- Mode test / simulation (`--test`)
- Liste des backups disponibles
- Arrêt automatique des containers concernés
- Suppression et recréation propre du volume
- Redémarrage automatique des containers

---

## Arborescence recommandée

```text
/opt/docker/backups/
├── archive/              # Backups (.tar.gz)
├── log/                  # Logs
│   ├── backup.log
│   └── restore.log
└── script/
    ├── backup_volumes.sh
    ├── restore_volume.sh
    ├── .env
    └── exclude.txt
