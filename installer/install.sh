#!/usr/bin/env bash
# Installation de Patiento sur un Raspberry Pi (Raspberry Pi OS Bookworm ou Trixie, avec bureau).
#
#   sudo ./installer/install.sh                  installation standard
#   sudo ./installer/install.sh --avec-voix      + voix française de qualité (Piper, hors ligne)
#   sudo ./installer/install.sh --certificat serveur.crt --cle serveur.key
#                                                certificat HTTPS fourni par l'établissement
#                                                (sinon : autorité locale générée automatiquement)
#
# Relancer le script met à jour l'application sans toucher aux données.
set -euo pipefail

APP_SRC="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR=/opt/patiento
DATA_DIR=/var/lib/patiento
SVC_USER=appel
PORT="${APPEL_PORT:-80}"
KIOSK_USER="${SUDO_USER:-}"
AVEC_VOIX=0
CERTIFICAT=""
CLE=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --avec-voix) AVEC_VOIX=1 ;;
    --certificat) CERTIFICAT="${2:-}"; shift ;;
    --cle) CLE="${2:-}"; shift ;;
    *) echo "Option inconnue : $1" >&2; exit 1 ;;
  esac
  shift
done
if [[ -n "$CERTIFICAT$CLE" ]]; then
  [[ -s "$CERTIFICAT" && -s "$CLE" ]] || { echo "--certificat et --cle doivent désigner deux fichiers existants." >&2; exit 1; }
  if [[ "$(openssl x509 -in "$CERTIFICAT" -noout -pubkey 2>/dev/null)" != "$(openssl pkey -in "$CLE" -pubout 2>/dev/null)" ]]; then
    echo "Le certificat et la clé ne correspondent pas (ou un des fichiers est illisible)." >&2; exit 1
  fi
fi
VOIX_NOM=fr_FR-siwis-medium
VOIX_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR/siwis/medium"

if [[ $EUID -ne 0 ]]; then echo "À lancer avec sudo." >&2; exit 1; fi
if [[ -z "$KIOSK_USER" || "$KIOSK_USER" == root ]]; then
  echo "Lancer avec sudo depuis le compte qui ouvre la session du bureau (ex. : pi)." >&2; exit 1
fi
KIOSK_HOME="$(getent passwd "$KIOSK_USER" | cut -d: -f6)"

echo "==> Paquets système"
apt-get update
apt-get install -y python3 python3-venv curl openssl poppler-utils libreoffice-impress \
  fonts-crosextra-carlito fonts-crosextra-caladea fonts-liberation2 fonts-dejavu-core
command -v chromium >/dev/null || command -v chromium-browser >/dev/null || \
  apt-get install -y chromium || apt-get install -y chromium-browser

echo "==> Application"
id -u "$SVC_USER" >/dev/null 2>&1 || \
  useradd --system --home-dir "$DATA_DIR" --shell /usr/sbin/nologin "$SVC_USER"
install -d -o "$SVC_USER" -g "$SVC_USER" -m 750 "$DATA_DIR"
install -d "$APP_DIR"
rm -rf "$APP_DIR/static"
cp -r "$APP_SRC/server.py" "$APP_SRC/static" "$APP_DIR/"

PYTHON=/usr/bin/python3
ENV_VOIX=""
if [[ $AVEC_VOIX -eq 1 ]]; then
  echo "==> Voix française (Piper)"
  [[ -d "$APP_DIR/venv" ]] || python3 -m venv "$APP_DIR/venv"
  "$APP_DIR/venv/bin/pip" install --upgrade piper-tts
  install -d "$APP_DIR/voix"
  for f in "$VOIX_NOM.onnx" "$VOIX_NOM.onnx.json"; do
    [[ -s "$APP_DIR/voix/$f" ]] || curl -fL -o "$APP_DIR/voix/$f" "$VOIX_URL/$f"
  done
  PYTHON="$APP_DIR/venv/bin/python"
  ENV_VOIX="Environment=APPEL_TTS_MODEL=$APP_DIR/voix/$VOIX_NOM.onnx"
fi

echo "==> Certificats HTTPS"
install -m 755 "$APP_SRC/installer/certificats.sh" /usr/local/sbin/patiento-certificats
if [[ -n "$CERTIFICAT" ]]; then
  # Certificat de l'établissement : il remplace l'autorité locale, plus rien à installer sur les postes.
  install -d -m 755 "$DATA_DIR/tls"
  rm -f "$DATA_DIR/tls/ca.crt" "$DATA_DIR/tls/ca.key" "$DATA_DIR/tls/serveur.san"
  install -m 644 "$CERTIFICAT" "$DATA_DIR/tls/serveur.crt"
  install -m 600 -o "$SVC_USER" "$CLE" "$DATA_DIR/tls/serveur.key"
  touch "$DATA_DIR/tls/fourni"
  openssl x509 -in "$DATA_DIR/tls/serveur.crt" -noout -subject -enddate
fi
/usr/local/sbin/patiento-certificats "$DATA_DIR/tls" "$SVC_USER"
cat > /etc/systemd/system/patiento-certificats.service <<EOF
[Unit]
Description=Renouvellement du certificat HTTPS de Patiento

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/patiento-certificats $DATA_DIR/tls $SVC_USER --redemarrer
EOF
cat > /etc/systemd/system/patiento-certificats.timer <<EOF
[Unit]
Description=Vérification mensuelle du certificat HTTPS de Patiento

[Timer]
OnCalendar=monthly
Persistent=true

[Install]
WantedBy=timers.target
EOF

echo "==> Service"
cat > /etc/systemd/system/patiento.service <<EOF
[Unit]
Description=Patiento (écran de salle d'attente)
After=network-online.target
Wants=network-online.target

[Service]
User=$SVC_USER
Environment=APPEL_PORT=$PORT
Environment=APPEL_DATA=$DATA_DIR
Environment=HOME=$DATA_DIR
$ENV_VOIX
ExecStart=$PYTHON $APP_DIR/server.py
Restart=always
RestartSec=3
AmbientCapabilities=CAP_NET_BIND_SERVICE
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
PrivateTmp=true
ReadWritePaths=$DATA_DIR

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable patiento
systemctl enable --now patiento-certificats.timer
systemctl restart patiento

echo "==> Écran en mode kiosque"
cat > /usr/local/bin/appel-kiosque <<EOF
#!/bin/sh
URL="http://localhost:$PORT/ecran"
until curl -fs -o /dev/null "\$URL"; do sleep 2; done
NAVIGATEUR=\$(command -v chromium || command -v chromium-browser)
exec "\$NAVIGATEUR" --kiosk --noerrdialogs --disable-infobars --no-first-run \\
  --disable-session-crashed-bubble --disable-features=Translate --password-store=basic \\
  --autoplay-policy=no-user-gesture-required --check-for-update-interval=31536000 "\$URL"
EOF
chmod 755 /usr/local/bin/appel-kiosque
install -d -o "$KIOSK_USER" -g "$KIOSK_USER" "$KIOSK_HOME/.config/autostart"
cat > "$KIOSK_HOME/.config/autostart/appel-kiosque.desktop" <<EOF
[Desktop Entry]
Type=Application
Name=Écran salle d'attente
Exec=/usr/local/bin/appel-kiosque
X-GNOME-Autostart-enabled=true
EOF
chown "$KIOSK_USER:" "$KIOSK_HOME/.config/autostart/appel-kiosque.desktop"

if command -v raspi-config >/dev/null; then
  raspi-config nonint do_boot_behaviour B4 || true   # ouverture automatique du bureau
  raspi-config nonint do_blanking 1 || true          # pas de mise en veille de l'écran
fi

IP="$(hostname -I | awk '{print $1}')"
SUFFIXE=""; [[ "$PORT" != 80 ]] && SUFFIXE=":$PORT"
echo
echo "Installation terminée."
echo "  Accueil   : https://$IP/"
echo "  Contenus  : https://$IP/contenus"
echo "  Appel     : https://$IP/appel?salle=N"
echo
if [[ -f "$DATA_DIR/tls/ca.crt" ]]; then
  echo "Autorité locale : chaque poste est guidé pour l'installer à sa première connexion."
  echo "  Guide     : http://$IP$SUFFIXE/certificat"
  echo "  Empreinte SHA-256 : $(openssl x509 -in "$DATA_DIR/tls/ca.crt" -noout -fingerprint -sha256 | cut -d= -f2)"
  echo "  Empreinte SHA-1 (affichée par Windows) : $(openssl x509 -in "$DATA_DIR/tls/ca.crt" -noout -fingerprint -sha1 | cut -d= -f2)"
else
  echo "Certificat fourni par l'établissement : rien à installer sur les postes qui font confiance à son autorité."
fi
echo "Redémarrez le Raspberry Pi (sudo reboot) pour lancer l'écran en plein écran."
