# 🧭 Riveria-it Dashboard

Ein modernes, an **Heimdall** angelehntes Start-Dashboard mit Kacheln, Uhrzeit, Theme-System, Hintergrundbild, **Wake-on-LAN (manuell verwaltbar)** und persistentem **Server-Speicher über PHP/Apache**.

---

## 🚀 Quick Install (Einzeiler)

**Variante 1 – `curl` (empfohlen):**
```bash
curl -fsSL https://raw.githubusercontent.com/Riveria-IT/riveria-it_my_dashboard_1.0/main/install_dashboard.sh | sudo bash
```

**Variante 2 – `wget`:**
```bash
wget -qO- https://raw.githubusercontent.com/Riveria-IT/riveria-it_my_dashboard_1.0/main/install_dashboard.sh | sudo bash
```

**Optional – mit Parametern (Branch/Webroot setzen):**
```bash
curl -fsSL https://raw.githubusercontent.com/Riveria-IT/riveria-it_my_dashboard_1.0/main/install_dashboard.sh \
| sudo env REPO_BRANCH=main WEBROOT=/var/www/html bash
```

Nach der Installation im Browser öffnen:
```
http://<server-ip>/
```

---

## 📁 Projektstruktur

```
/var/www/html/
├── index.html
├── style.css
├── app.js
└── api/
    ├── config.php
    ├── load.php
    ├── save.php
    ├── wol.php          # (optional, PHP-WOL API)
    ├── .htaccess
    └── data/
```

---

## ⚙️ 1. Voraussetzungen

### Variante A – Nur lokal (Test)
- Kein Server nötig  
- Öffne einfach **index.html** direkt im Browser  
- Alle Daten werden im **localStorage** des Browsers gespeichert  

### Variante B – Mit Server (empfohlen)
Damit mehrere Benutzer (z. B. im LAN) dasselbe Dashboard teilen:

**Systemanforderungen**
- Linux-Server oder Raspberry Pi  
- Apache2 + PHP (≥ 7.4)  
- Schreibrechte für den Apache-User (`www-data`)

---

## 🏗️ 2. Installation (Server-Variante)

```bash
# Apache & PHP installieren
sudo apt update
sudo apt install -y apache2 php libapache2-mod-php php-sockets
sudo a2enmod headers rewrite
sudo systemctl restart apache2
```

### Projektdateien kopieren
```bash
sudo rm -rf /var/www/html/*
sudo cp -r ./riveria-dashboard/* /var/www/html/
```

### Rechte setzen
```bash
sudo mkdir -p /var/www/html/api/data
sudo chown -R www-data:www-data /var/www/html/api/data
sudo chmod -R 775 /var/www/html/api/data
```

📂 Öffne dein Dashboard im Browser:  
➡️ **http://<server-ip>/**

---

## 🌐 3. API-Endpunkte

Die API speichert alle Einstellungen serverseitig als JSON unter:  
`/var/www/html/api/data/<clientId>.json`

### Test mit cURL
```bash
curl "http://localhost/api/load.php?clientId=test123"

curl -X POST "http://localhost/api/save.php"   -H "Content-Type: application/json"   -d '{"clientId":"test123","data":{"tiles":[{"title":"Google","url":"https://google.com"}]}}'
```

---

## 🖼️ 4. Funktionen

### 🔹 Kacheln
- Webseitenlinks mit **Titel, URL, Beschreibung und Icon**  
- Icon-Optionen: Auto (Favicon) · URL · Upload (PNG/JPG/SVG)  
- Klick → öffnet neuen Tab  
- Menü ( … ) → **Bearbeiten / Löschen**

### 🔹 Hintergrund
- Eigenes Bild (automatisch auf ~1920 px skaliert)  
- Blur- & Abdunklungs-Regler  
- Wird als **Base64** im JSON gespeichert  

### 🔹 Theme
- Frei wählbare Farbpalette inkl. Transparenz  
- Taskbar & Kacheln übernehmen denselben Farbton  
- Einstellungen bleiben dauerhaft gespeichert  

### 🔹 Wake-on-LAN (vollständig integriert)
- Geräte manuell hinzufügen, bearbeiten oder löschen  
- Speichert pro Gerät:  
  - Name  
  - MAC-Adresse  
  - Broadcast-Adresse (z. B. `255.255.255.255` oder `192.168.x.255`)  
  - Port (Standard 9)  
  - Endpoint (z. B. `http://<server-ip>/api/wol.php` oder Flask-API)  
- Jedes Gerät kann seinen **eigenen Endpoint** verwenden  
- Sendet **Magic Packet** über REST-API  
- Alle Geräte werden **lokal und serverseitig** gespeichert

---

## 💡 5. Wake-on-LAN API (Optionen)

### 🧩 Variante A – PHP (empfohlen)
Kein zusätzlicher Dienst nötig, läuft direkt über Apache.

```bash
sudo apt install -y php-sockets
sudo systemctl restart apache2
```

**Datei:** `/var/www/html/api/wol.php`
```php
<?php
header('Content-Type: application/json; charset=utf-8');
if ($_SERVER['REQUEST_METHOD'] !== 'POST') { http_response_code(405); echo json_encode(['error'=>'Method not allowed']); exit; }
$in = json_decode(file_get_contents('php://input'), true) ?: [];
$mac = $in['mac'] ?? '';
$addr = $in['address'] ?? '255.255.255.255';
$port = intval($in['port'] ?? 9);

if (!preg_match('/^([0-9A-Fa-f]{2}[:\-]){5}([0-9A-Fa-f]{2})$/', $mac)) {
  http_response_code(400); echo json_encode(['error'=>'invalid mac']); exit;
}
$mac = str_replace([':', '-'], '', $mac);
$data = '';
for ($i=0; $i<6; $i++) $data .= chr(0xFF);
for ($i=0; $i<16; $i++) $data .= pack('H12', $mac);

$socket = socket_create(AF_INET, SOCK_DGRAM, SOL_UDP);
socket_set_option($socket, SOL_SOCKET, SO_BROADCAST, 1);
$ok = socket_sendto($socket, $data, strlen($data), 0, $addr, $port);
socket_close($socket);

if ($ok === false) { http_response_code(500); echo json_encode(['error'=>'send failed']); exit; }
echo json_encode(['ok'=>true]);
```
📡 **Endpoint im Dashboard:**  
```
http://<server-ip>/api/wol.php
```

---

### 🐍 Variante B – Python / Flask (optional)
Für Nutzer, die lieber einen separaten Dienst verwenden möchten:
```bash
sudo apt install -y python3 python3-venv
python3 -m venv ~/wolapi
source ~/wolapi/bin/activate
pip install flask
```

**Datei:** `~/wolapi/wol_api.py`
```python
from flask import Flask, request, jsonify
import socket, struct

app = Flask(__name__)

def wake_on_lan(mac, broadcast="255.255.255.255", port=9):
    mac_bytes = bytes.fromhex(mac.replace(":", "").replace("-", ""))
    magic = b"\xff" * 6 + mac_bytes * 16
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.sendto(magic, (broadcast, port))

@app.post("/wol")
def wol():
    data = request.json
    mac = data.get("mac")
    addr = data.get("address", "255.255.255.255")
    port = int(data.get("port", 9))
    wake_on_lan(mac, addr, port)
    return jsonify({"ok": True})

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8787)
```

**Starten:**
```bash
source ~/wolapi/bin/activate
python ~/wolapi/wol_api.py
```

📡 **Endpoint im Dashboard:**  
```
http://<server-ip>:8787/wol
```

---

## 🔒 6. Sicherheit

`.htaccess` in `/api/` schützt vor Directory-Listing:
```
Options -Indexes
Header always set X-Content-Type-Options "nosniff"
Header always set Cache-Control "no-store"
```

HTTPS aktivieren:
```bash
sudo apt install -y certbot python3-certbot-apache
sudo certbot --apache
```

---

## 💾 7. Backup

Alle gespeicherten Einstellungen und WOL-Geräte liegen unter:
```
/var/www/html/api/data/
```

Backup erstellen:
```bash
tar czf dashboard-backup-$(date +%F).tar.gz /var/www/html/api/data
```

---

## 🧠 8. Tipps

- Für **LAN-Geräte** empfiehlt sich der **PHP-WOL-Endpoint**, da kein separater Dienst läuft.  
- Jedes Gerät kann einen eigenen **Endpoint** definieren.  
- Im **Theme-Dialog** kannst du Topbar- und Kachel-Farben per Farbpalette abstimmen.  
- Alle Einstellungen werden **lokal (Browser)** und **serverseitig (JSON)** gespeichert.

---

## 🧡 9. Credits

**Projektidee:** inspiriert von *Heimdall*  
**Entwicklung:** Riveria IT  
**Frontend:** HTML + CSS + Vanilla JS  
**Backend:** PHP (JSON-Filesystem-Storage)  
**Design:** Modern Glass UI mit Blur, Schatten & Farbverlauf  

---

> 💬 *Made with ❤️ by Riveria IT – Switzerland*
