# Docker Volume Backup & Restore

Scripts Bash permettant la **sauvegarde** et la **restauration fiable de volumes Docker**, avec gestion des containers, rotation des logs et politique de rétention.

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
├── README.md
├── archive/              # Backups (.tar.gz)
├── log/                  # Logs
│   ├── backup.log
│   └── restore.log
└── script/
    ├── backup_volumes.sh
    ├── restore_volume.sh
    ├── .env
    └── exclude.txt
```

---
## Déploiement et utilisation

## Installation rapide (GitHub)

```bash
mkdir -p /opt/docker/backups/{archive,log,script}
touch /opt/docker/backups/log/{backup.log,restore.log}
cd /opt/docker/
# Cloner le projet
git clone https://github.com/Lucciano-stn/docker_volume-backup.git backups
cd backups/script
chmod +x backup_volumes.sh
chmod +x restore_volume.sh
```

## Alternative manuelle (sans Git) :

```bash
mkdir -p /opt/docker/backups/{archive,log,script}
touch /opt/docker/backups/log/{backup.log,restore.log}
cd /opt/docker/backups/
# Télécharger ZIP ou copier les fichiers
cd script
chmod +x backup_volumes.sh
chmod +x restore_volume.sh
```

## Vérification

```bash
cd /opt/docker/backups/script
./backup_volumes.sh man
```

Si l’aide s’affiche, l’installation est correcte.

## Paramètres d'environnement disponibles

L'ensemble des paramètres ci-dessous sont disponibles dans le fichier .env.

```bash
BACKUP_DIR="/opt/docker/backups/archive"
RETENTION_DAYS=3
BACKUP_LOG_FILE="/opt/docker/backups/log/backup.log"
LOG_MAX_SIZE_MB=10
LOG_MAX_ROTATE=5
STOP_CONTAINERS=true
DATE_FORMAT="%Y%m%d_%H%M"
EXCLUDE_FILE="/opt/docker/backups/script/exclude.txt"
RESTORE_LOG_FILE="/opt/docker/backups/log/restore.log"
DRY_RUN=false  # true=simulation, false=réel
```
## Exclusion de volumes

Les volumes contenus dans le fichier exclude.txt ne sont jamais sauvegardés.

```bash
temp_
cache_
.*backup.*
logs_
tmp_
```

## Logs utiles 

- Sauvegarde : /opt/docker/backups/log/backup.log
- Restauration : /opt/docker/backups/log/restore.log

## Déploiement automatique via Cron

Ce projet peut être exécuté automatiquement à l’aide de **cron** afin de planifier des sauvegardes régulières (ex : quotidiennes).
```bash
 Example of job definition:
# .---------------- minute (0 - 59)
# |  .------------- hour (0 - 23)
# |  |  .---------- day of month (1 - 31)
# |  |  |  .------- month (1 - 12) OR jan,feb,mar,apr ...
# |  |  |  |  .---- day of week (0 - 6) (Sunday=0 or 7) OR sun,mon,tue,wed,thu,fri,sat
# |  |  |  |  |
# *  *  *  *  * user-name command to be executed

  0  2  *  *  * root /opt/docker/backups/script/backup_volumes.sh >/dev/null 2>&1
```


## Licence

Copyright (c) 2026 Luciano Sautron  
All rights reserved.

Ce projet est destiné à un **usage interne ou privé**.

Toute redistribution, modification ou utilisation publique du code
doit mentionner explicitement l’auteur.

Aucune garantie n’est fournie. L’auteur ne saurait être tenu responsable
des dommages directs ou indirects résultant de l’utilisation de ce projet.
