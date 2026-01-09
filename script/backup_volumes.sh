#!/bin/bash
# backup_volumes.sh - Backup volumes Docker 
#
# Auteur       : Luciano Sautron
# Année        : 2026
#
# Description  :
#   Sauvegarde des volumes Docker avec gestion des containers,
#   rotation des logs, politique de rétention et mode hot backup.
#
# Usage :
#   ./backup_volumes.sh [volume1 volume2] [--hotbackup]
#
# Licence :
#   Copyright (c) 2026 Luciano Sautron
#   All rights reserved.
#
#   Usage interne ou privé autorisé.
#   Toute redistribution, modification ou utilisation publique
#   doit mentionner explicitement l’auteur.
#

# Version : 1.0.0
# Dernière mise à jour : 2026-01-08

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/.env"

DATE=$(date +"$DATE_FORMAT")
ERROR_CONTAINERS=()

## ========================================
## SECTION 1: MAN PAGE
## ========================================
show_man() {
    cat << 'EOF'
NAME
    backup_volumes.sh - Backup volumes Docker

SYNOPSIS
    ./backup_volumes.sh                    # TOUS volumes (stop)
    ./backup_volumes.sh volume1 [volume2]  # Noms exacts (stop)
    ./backup_volumes.sh volume1 --hotbackup # + HOTBACKUP (no stop)
    ./backup_volumes.sh man

EXEMPLES
    # Backup tous les volumes (avec arrêt containers)
    ./backup_volumes.sh
    
    # Backup volume spécifique (avec arrêt)
    ./backup_volumes.sh 001-prod-elaguila-wp-primary
    
    # Backup plusieurs volumes (avec arrêt)
    ./backup_volumes.sh 001-prod-elaguila-wp-primary 002-prod-cache-redis
    
    # Backup HOT (sans arrêt containers)
    ./backup_volumes.sh 001-prod-elaguila-wp-primary --hotbackup

OPTIONS
    --hotbackup, -hb    Backup en direct (sans arrêter les containers)
    man, --help, -h     Affiche cette aide
EOF
    exit 0
}

## ========================================
## SECTION 2: LOGS ROTATIFS - FIX
## ========================================
BACKUP_LOG_FILE="/opt/docker/backups/log/backup.log"
[ ! -d "$(dirname "$BACKUP_LOG_FILE")" ] && mkdir -p "$(dirname "$BACKUP_LOG_FILE")"

rotate_log() {
    MAX_SIZE=$((LOG_MAX_SIZE_MB*1024*1024))
    MAX_ROTATE=$LOG_MAX_ROTATE
    [ $(stat -c%s "$BACKUP_LOG_FILE" 2>/dev/null || echo 0) -ge $MAX_SIZE ] && {
        for i in $(seq $((MAX_ROTATE-1)) -1 0); do
            [ -f "$BACKUP_LOG_FILE.$i" ] && mv "$BACKUP_LOG_FILE.$i" "$BACKUP_LOG_FILE.$((i+1))"
        done
        mv "$BACKUP_LOG_FILE" "$BACKUP_LOG_FILE.1"
        touch "$BACKUP_LOG_FILE"
        echo "=== LOG ROTATED $(date) ===" > "$BACKUP_LOG_FILE"
    }
}

log() {
    rotate_log
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$BACKUP_LOG_FILE" 2>/dev/null
}

## ========================================
## SECTION 3: MAN CHECK
## ========================================
[ "$1" = "man" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ] && show_man

## ========================================
## SECTION 4: INITIALISATION + VOLUMES - FIX
## ========================================
[ ! -f "$EXCLUDE_FILE" ] && touch "$EXCLUDE_FILE"
mkdir -p "$BACKUP_DIR"
cd "$BACKUP_DIR" || exit 1

# HOTBACKUP = DERNIER argument exact
IS_HOTBACKUP=false
if [ "${!#}" = "--hotbackup" ]; then
    IS_HOTBACKUP=true
fi

# ✅ FIX : Définir STOP_CONTAINERS ICI (AVANT log())
STOP_CONTAINERS=true
[ "$IS_HOTBACKUP" = true ] && STOP_CONTAINERS=false

# Volumes = TOUS arguments sauf --hotbackup/man
VOLUMES=()
for ((i=1; i<= $#; i++)); do
    arg="${!i}"
    if [[ "$arg" != "--hotbackup" && "$arg" != "man" && "$arg" != "--help" && "$arg" != "-h" ]]; then
        VOLUMES+=("$arg")
    fi
done

# Mode
if [ ${#VOLUMES[@]} -eq 0 ]; then
    mapfile -t VOLUMES < <(docker volume ls -q --filter driver=local | \
        grep -v -f "$EXCLUDE_FILE" -E -i | sort)
    log "🌐 TOUS VOLUMES: ${#VOLUMES[@]} (stop containers)"
else
    if [ "$IS_HOTBACKUP" = true ]; then
        log "🎯 ${#VOLUMES[@]} volume(s) [HOTBACKUP - sans stop]"
    else
        log "✅ ${#VOLUMES[@]} volume(s) [NORMAL - stop containers]"
    fi
fi

## ========================================
## SECTION 5: VÉRIFICATION VOLUMES
## ========================================
VALID_VOLUMES=()
for vol in "${VOLUMES[@]}"; do
    if docker volume inspect "$vol" >/dev/null 2>&1; then
        VALID_VOLUMES+=("$vol")
    else
        log "❌ N'EXISTE PAS: $vol"
    fi
done

VOLUMES=("${VALID_VOLUMES[@]}")
[ ${#VOLUMES[@]} -eq 0 ] && { 
    log "🚫 AUCUN volume valide" 
    exit 1 
}
log "✅ ${#VOLUMES[@]} valide(s)"

## ========================================
## SECTION 6: BACKUP - MAINTENANT OK
## ========================================
SUCCESS_COUNT=0
for vol in "${VOLUMES[@]}"; do
    log "🔄 $vol"
    
    if [ "$STOP_CONTAINERS" = true ]; then  # ✅ Variable définie !
        CONTAINERS=$(docker ps -q --filter volume="$vol")
        if [ -n "$CONTAINERS" ]; then
            log "   ⏹️  Stop: $CONTAINERS"
            docker stop $CONTAINERS >/dev/null 2>&1 || docker kill $CONTAINERS >/dev/null 2>&1 || {
                log "   ❌ Bloqué → Skip"
                continue
            }
            sleep 3
        else
            log "   ℹ️  Pas de container"
        fi
    else
        log "   🔥 MODE HOTBACKUP"
    fi
    
    BACKUP_FILE="${vol}_${DATE}.tar.gz"
    log "   💾 $BACKUP_FILE"
    if docker run --rm -v "$vol":/data -v "$BACKUP_DIR":/backup ubuntu \
        tar czf "/backup/$BACKUP_FILE" -C /data . >/dev/null 2>&1 && \
        [ -s "$BACKUP_FILE" ]; then
        SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
        log "   ✓ OK ($SIZE)"
        ((SUCCESS_COUNT++))
    else
        log "   ✗ ÉCHEC"
        rm -f "$BACKUP_FILE" 2>/dev/null
    fi
    
    if [ "$STOP_CONTAINERS" = true ] && [ -n "$CONTAINERS" ]; then
        log "   ▶️  Restart: $CONTAINERS"
        docker start $CONTAINERS >/dev/null 2>&1 && sleep 5 || log "   ❌ Restart KO"
    fi
    echo "---"
done

## ========================================
## SECTION 7: FIN
## ========================================
log "📊 $SUCCESS_COUNT/${#VOLUMES[@]} réussis"
OLD_COUNT=$(find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS | wc -l)
find "$BACKUP_DIR" -name "*.tar.gz" -mtime +$RETENTION_DAYS -delete
[ "$OLD_COUNT" -gt 0 ] && log "🧹 $OLD_COUNT supprimés (rétention $RETENTION_DAYS jours)"

log "💾 $(df -h "$BACKUP_DIR" | tail -1)"
log "✅ TERMINÉ"
