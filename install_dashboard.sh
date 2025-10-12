#!/usr/bin/env bash
set -euo pipefail

# ===============================
# Riveria Dashboard – Installer
# Ubuntu / Debian
# ===============================
REPO_URL="${REPO_URL:-https://github.com/Riveria-IT/riveria-it_my_dashboard_1.0.git}"
REPO_BRANCH="${REPO_BRANCH:-main}"     # anpassen falls dein Default-Branch anders heißt
WEBROOT="${WEBROOT:-/var/www/html}"    # Zielordner (DocumentRoot)
APACHE_USER="${APACHE_USER:-www-data}"
APACHE_GROUP="${APACHE_GROUP:-www-data}"

echo "==> Repo:     $REPO_URL (branch: $REPO_BRANCH)"
echo "==> Webroot:  $WEBROOT"
echo "==> Apache:   user=$APACHE_USER group=$APACHE_GROUP"
echo

# Root-Check
if [[ $EUID -ne 0 ]]; then
  echo "Bitte als root starten: sudo bash install_dashboard.sh"; exit 1
fi
export DEBIAN_FRONTEND=noninteractive

echo "==> Pakete installieren"
apt-get update -y
apt-get install -y apache2 php libapache2-mod-php php-sockets git unzip curl

echo "==> Apache-Module aktivieren"
a2enmod headers rewrite >/dev/null || true

# AllowOverride sauber per eigener Conf aktivieren (statt sed im apache2.conf)
echo "==> AllowOverride per eigener Conf aktivieren"
cat >/etc/apache2/conf-available/riveria-override.conf <<'EOFCONF'
<Directory /var/www/>
    AllowOverride All
</Directory>
EOFCONF
a2enconf riveria-override >/dev/null || true

# UFW (falls aktiv) öffnen
if command -v ufw >/dev/null 2>&1 && ufw status | grep -q "Status: active"; then
  echo "==> UFW: Apache Full erlauben"
  ufw allow 'Apache Full' || true
fi

systemctl enable apache2 >/dev/null || true
systemctl restart apache2

# Repo klonen (shallow)
WORKDIR="$(mktemp -d)"
echo "==> Klone Repository in $WORKDIR"
git clone --depth=1 --branch "$REPO_BRANCH" "$REPO_URL" "$WORKDIR/repo"

# Webroot vorbereiten (Backup + leerräumen)
echo "==> Zielordner vorbereiten: $WEBROOT"
mkdir -p "$WEBROOT"
STAMP="$(date +%Y%m%d-%H%M%S)"
if [ -n "$(ls -A "$WEBROOT" 2>/dev/null || true)" ]; then
  echo "==> Backup: ${WEBROOT}_backup_${STAMP}.tar.gz"
  tar czf "${WEBROOT}_backup_${STAMP}.tar.gz" -C "$WEBROOT" .
  rm -rf "${WEBROOT:?}/"*
fi

# Dateien kopieren
echo "==> Dateien kopieren"
cp -r "$WORKDIR/repo/"* "$WEBROOT/" || true

# Server-Speicher
mkdir -p "$WEBROOT/api/data"

# Falls wol.php im Repo fehlt: Minimal-Implementierung bereitstellen
if [ ! -f "$WEBROOT/api/wol.php" ]; then
  echo "==> wol.php nicht gefunden – Standard-wol.php wird erstellt"
  cat > "$WEBROOT/api/wol.php" <<'PHPEOF'
<?php
header('Content-Type: application/json; charset=utf-8');
if ($_SERVER['REQUEST_METHOD'] !== 'POST') { http_response_code(405); echo json_encode(['error'=>'Method not allowed']); exit; }
if (!function_exists('socket_create')) { http_response_code(500); echo json_encode(['error'=>'php-sockets extension missing']); exit; }
$in = json_decode(file_get_contents('php://input'), true) ?: [];
$mac = $in['mac'] ?? '';
$addr = $in['address'] ?? '255.255.255.255';
$port = intval($in['port'] ?? 9);
if (!preg_match('/^([0-9A-Fa-f]{2}[:\\-]){5}([0-9A-Fa-f]{2})$/', $mac)) { http_response_code(400); echo json_encode(['error'=>'invalid mac']); exit; }
$mac = str_replace([':', '-'], '', $mac);
$data = str_repeat(chr(0xFF), 6) . str_repeat(pack('H12', $mac), 16);
$sock = @socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
if ($sock === false) { http_response_code(500); echo json_encode(['error'=>'socket_create failed']); exit; }
@socket_set_option($sock, SOL_SOCKET, SO_BROADCAST, 1);
$ok = @socket_sendto($sock, $data, strlen($data), 0, $addr, $port);
$err = socket_last_error($sock);
@socket_close($sock);
if ($ok === false || $err) { http_response_code(500); echo json_encode(['error'=>'send failed','detail'=>socket_strerror($err)]); exit; }
echo json_encode(['ok'=>true]);
PHPEOF
fi

# .htaccess Security in /api/ (falls fehlt)
if [ ! -f "$WEBROOT/api/.htaccess" ]; then
  echo "==> .htaccess in /api/ erstellen"
  cat > "$WEBROOT/api/.htaccess" <<'HTEOF'
Options -Indexes
Header always set X-Content-Type-Options "nosniff"
Header always set Cache-Control "no-store"
HTEOF
fi

# Rechte setzen
echo "==> Rechte setzen"
chown -R "$APACHE_USER:$APACHE_GROUP" "$WEBROOT"
find "$WEBROOT" -type d -exec chmod 755 {} \;
find "$WEBROOT" -type f -exec chmod 644 {} \;
chmod 775 "$WEBROOT/api/data"
chgrp "$APACHE_GROUP" "$WEBROOT/api/data"

# PHP-Sockets verifizieren
echo "==> Prüfe php-sockets Extension"
if ! php -m | grep -qi '^sockets$'; then
  echo "FEHLER: php-sockets nicht aktiv. Bitte PHP/Apache neu starten: sudo systemctl restart apache2"
  exit 2
fi

# Apache reload
systemctl restart apache2

# Kurzer Selbsttest (nur ob index.php/html erreichbar wäre)
IP=$(hostname -I 2>/dev/null | awk '{print $1}')
echo
echo "=========================================="
echo " Installation fertig 🎉"
echo " Webseite:       http://${IP:-<server-ip>}/"
echo " Webroot:        $WEBROOT"
echo " Repo-Quelle:    $REPO_URL (branch: $REPO_BRANCH)"
echo
echo " Server-Speicher: $WEBROOT/api/data (schreibbar für $APACHE_USER)"
echo " WOL-Endpoint:    http://${IP:-<server-ip>}/api/wol.php"
echo "=========================================="
