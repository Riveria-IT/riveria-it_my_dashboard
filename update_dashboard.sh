#!/usr/bin/env bash
set -euo pipefail

# ===============================
# Riveria Dashboard – UPDATE
# ===============================
REPO_URL="${REPO_URL:-https://github.com/Riveria-IT/riveria-it_my_dashboard_1.0.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"          # wie im Installer
WEBROOT="${WEBROOT:-/var/www/html}"         # Standard-Zielordner (DocumentRoot)

echo "==> UPDATE für Dashboard"
echo "==> Repo:     $REPO_URL (branch: $REPO_BRANCH)"
echo "==> Aktueller Webroot (Standard): $WEBROOT"
echo

# === Interaktive Abfrage Webroot ===
read -r -p "Hast du einen anderen Webroot-Ordner (z.B. /var/www/html/michael)? Wenn ja, Pfad eingeben, sonst einfach Enter: " NEW_WEBROOT
if [[ -n "$NEW_WEBROOT" ]]; then
  WEBROOT="$NEW_WEBROOT"
fi

echo "=> Verwendeter Webroot: $WEBROOT"
echo

# Root-Check
if [[ $EUID -ne 0 ]]; then
  echo "Bitte als root starten: sudo bash update_dashboard.sh"
  exit 1
fi

# Minimal: git sicherstellen
if ! command -v git >/dev/null 2>&1; then
  echo "==> git fehlt, wird installiert"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y git
fi

if [ ! -d "$WEBROOT" ]; then
  echo "FEHLER: Webroot $WEBROOT existiert nicht."
  exit 1
fi

# Daten-Verzeichnis merken
DATA_DIR="$WEBROOT/api/data"

# Temp-Ordner
WORKDIR="$(mktemp -d)"
echo "==> Klone Repository in $WORKDIR"
git clone --depth=1 --branch "$REPO_BRANCH" "$REPO_URL" "$WORKDIR/repo"

# Backup anlegen (komplettes Webroot)
STAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP="${WEBROOT}_update_backup_${STAMP}.tar.gz"
echo "==> Backup: $BACKUP"
tar czf "$BACKUP" -C "$WEBROOT" .

# /api/data temporär retten, falls vorhanden
KEEP_DATA_DIR="$WORKDIR/_api_data_keep"
if [ -d "$DATA_DIR" ]; then
  echo "==> Bestehende Daten in $DATA_DIR werden erhalten"
  mkdir -p "$(dirname "$KEEP_DATA_DIR")"
  mv "$DATA_DIR" "$KEEP_DATA_DIR"
fi

# Webroot leeren
echo "==> Webroot reinigen"
rm -rf "${WEBROOT:?}/"*

# Neue Dateien aus Repo kopieren
echo "==> Neue Dateien kopieren"
cp -r "$WORKDIR/repo/"* "$WEBROOT/" || true

# api/data wiederherstellen oder neu anlegen
mkdir -p "$WEBROOT/api"
if [ -d "$KEEP_DATA_DIR" ]; then
  echo "==> api/data wiederherstellen"
  mv "$KEEP_DATA_DIR" "$WEBROOT/api/data"
else
  echo "==> api/data neu anlegen (keine alten Daten gefunden)"
  mkdir -p "$WEBROOT/api/data"
fi

# Rechte anpassen (falls nötig)
if id www-data >/dev/null 2>&1; then
  echo "==> Rechte an www-data setzen"
  chown -R www-data:www-data "$WEBROOT"
  find "$WEBROOT" -type d -exec chmod 755 {} \;
  find "$WEBROOT" -type f -exec chmod 644 {} \;
  chmod 775 "$WEBROOT/api/data"
fi

# Apache reload (nicht zwingend, aber sauber)
if command -v systemctl >/dev/null 2>&1; then
  echo "==> Apache neu laden"
  systemctl reload apache2 || systemctl restart apache2 || true
fi

IP=$(hostname -I 2>/dev/null | awk '{print $1}')

echo
echo "=========================================="
echo " Update fertig 🎉"
echo " Webseite:        http://${IP:-<server-ip>}/"
echo " Webroot:         $WEBROOT"
echo " Backup:          $BACKUP"
echo " Server-Speicher: $WEBROOT/api/data (wurde erhalten)"
echo "=========================================="
