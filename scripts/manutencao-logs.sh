#!/usr/bin/env bash
# Script de manutencao e rotacao de logs
APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGS_DIR="$APP_DIR/logs"
BACKUP_DIR="$APP_DIR/backups"
DATA_HORA=$(date +"%Y%m%d_%H%M%S")

mkdir -p "$BACKUP_DIR"
echo "[$(date)] Iniciando rotina de manutencao..." >> "$LOGS_DIR/manutencao.log"

if [ -f "$LOGS_DIR/access.log" ]; then
    cp "$LOGS_DIR/access.log" "$BACKUP_DIR/access_$DATA_HORA.log"
    echo "Backup de access.log gerado com sucesso: access_$DATA_HORA.log" >> "$LOGS_DIR/manutencao.log"
fi
