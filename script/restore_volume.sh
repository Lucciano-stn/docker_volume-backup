#!/bin/bash
# restore_volume.sh - Restaure volume Docker depuis backup EXACT
#
# Auteur       : Luciano Sautron
# Année        : 2026
#
# Description  :
#   Restaure un volume Docker depuis un backup existant (.tar.gz),
#   avec arrêt/restart automatique des containers et mode test.
#
# Usage :
#   ./restore_volume.sh <nom_backup> [--test]
#   ./restore_volume.sh --list
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
source "$SCRIPT_DIR/.env" 2>/dev/null || echo "⚠️  .env introuvable"

DATE=$(date +"%Y%m%d_%H%M")
RESTORE_LOG_FILE="/opt/docker/backups/log/restore.log"
mkdir -p "$(dirname "$RESTORE_LOG_FILE")"
BACKUP_DIR="/opt/docker/backups/archive"

## ========================================
## MAN PAGE
## ========================================
show_man() {
    cat << 'EOF'
NAME
    restore_volume.sh - Restaure volume Docker depuis backup EXACT

SYNOPSIS
    ./restore_volume.sh <nom_backup_complet> [--test]
    ./restore_volume.sh --list
    ./restore_volume.sh [man|-h|--help]

USAGE
    # Lister backups disponibles
    ./restore_volume.sh --list
    
    # Test restauration
    ./restore_volume.sh 001-wp_elaguila_wp_html_20260108_1558 --test
    
    # Restauration réelle
    ./restore_volume.sh 001-wp_elaguila_wp_html_20260108_1558

OPTIONS
    --list         Liste tous les backups disponibles
    --test         Mode simulation (rien modifié)
    man, -h, --help Aide

NOTES
    • NOM COMPLET du backup requis (sans .tar.gz)
EOF
    exit 0
}

## ========================================
## LOGGING
## ========================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$RESTORE_LOG_FILE" 2>&1
}

## ========================================
## LISTE BACKUPS (--list)
## ========================================
list_backups() {
    echo "📦 BACKUPS DISPONIBLES dans $BACKUP_DIR :"
    echo "----------------------------------------"
    
    if [ ! -d "$BACKUP_DIR" ]; then
        echo "❌ Répertoire $BACKUP_DIR introuvable"
        exit 1
    fi
    
    shopt -s nullglob
    BACKUP_FILES=("$BACKUP_DIR"/*.tar.gz)
    shopt -u nullglob
    
    if [ ${#BACKUP_FILES[@]} -eq 0 ]; then
        echo "   Aucun backup trouvé"
        exit 0
    fi
    
    # Grouper par volume
    for file in "${BACKUP_FILES[@]}"; do
        basename=$(basename "$file" .tar.gz)
        size=$(du -h "$file" | cut -f1)
        date=$(echo "$basename" | grep -o '[0-9]\{8\}_[0-9]\{4\}' || echo "inconnu")
        echo "  📁 $basename  ($size)  [$date]"
    done | sort -V
    
    echo ""
    echo "💡 Usage: ./restore_volume.sh NOM_BACKUP"
    echo "   ex: ./restore_volume.sh 001-wp_elaguila_wp_html_20260108_1558"
}

## ========================================
## PARSING ARGUMENTS
## ========================================
[ "$1" = "man" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ] && show_man
[ "$1" = "--list" ] && { list_backups; exit 0; }
[ $# -lt 1 ] && { echo "❌ Usage: $0 <backup_name> [--test] | --list"; show_man; }

BACKUP_NAME="$1"
TEST_MODE=false
[ "$2" = "--test" ] && TEST_MODE=true

# Extraire nom volume
VOLUME_NAME=$(echo "$BACKUP_NAME" | sed 's/_[0-9]\{8\}.*//')
BACKUP_FILE="$BACKUP_DIR/${BACKUP_NAME}.tar.gz"

# Vérifications
[ ! -f "$BACKUP_FILE" ] && {
    log "❌ Backup NON trouvé: $BACKUP_FILE"
    echo "💡 Liste complète:"
    list_backups
    exit 1
}

SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
log "=== RESTAURATION: $VOLUME_NAME depuis $BACKUP_NAME.tar.gz ($SIZE) ==="
[ "$TEST_MODE" = true ] && log "🧪 MODE TEST ACTIVÉ"

cd "$BACKUP_DIR" || { log "❌ Répertoire inaccessible"; exit 1; }

## ========================================
## STOP CONTAINERS
## ========================================
if [ "$TEST_MODE" = false ]; then
    CONTAINERS=$(docker ps -q --filter volume="$VOLUME_NAME" 2>/dev/null)
    if [ -n "$CONTAINERS" ]; then
        log "⏹️  Stop: $CONTAINERS"
        docker stop $CONTAINERS >/dev/null 2>&1 || docker kill $CONTAINERS >/dev/null 2>&1
        sleep 2
    else
        log "ℹ️  Pas de containers actifs"
    fi
else
    log "🧪 [TEST] Skip stop containers"
fi

## ========================================
## RESTAURATION
## ========================================
if [ "$TEST_MODE" = true ]; then
    log "🧪 [TEST] SIMULATION - Rien restauré"
else
    # Forcer suppression volume (containers déjà stoppés)
    if docker volume inspect "$VOLUME_NAME" >/dev/null 2>&1; then
        log "🗑️  rm volume: $VOLUME_NAME"
        docker volume rm -f "$VOLUME_NAME" >/dev/null 2>&1 || log "⚠️  Volume utilisé?"
    fi
    
    # Créer + restaurer
    log "💾 Restaurer depuis $BACKUP_NAME.tar.gz"
    docker volume create "$VOLUME_NAME"
    if docker run --rm -v "$VOLUME_NAME":/data -v "$BACKUP_DIR":/backup ubuntu \
        bash -c "tar xzf /backup/${BACKUP_NAME}.tar.gz -C /data"; then
        log "✅ ✅ RESTAURÉ ($SIZE)"
    else
        log "❌ ÉCHEC restauration"
        exit 1
    fi
    
    log "📂 Vérification:"
    docker run --rm -v "$VOLUME_NAME":/data busybox ls -lh /data | head -8
fi

## ========================================
## RESTART CONTAINERS
## ========================================
if [ "$TEST_MODE" = false ] && [ -n "$CONTAINERS" ]; then
    log "▶️  Start: $CONTAINERS"
    docker start $CONTAINERS >/dev/null 2>&1 && sleep 3 || log "❌ Erreur redémarrage"
else
    [ "$TEST_MODE" = true ] && log "🧪 [TEST] Skip restart containers"
fi

log "🎉 TERMINÉ: $VOLUME_NAME"
echo ""
echo "✅ $VOLUME_NAME restauré depuis $BACKUP_NAME.tar.gz"
[ "$TEST_MODE" = true ] && echo "🧪 MODE TEST = RIEN MODIFIÉ !"
echo "🔍 docker volume inspect $VOLUME_NAME"
