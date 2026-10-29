#!/usr/bin/env bash
# Certificats HTTPS de Patiento : une autorité locale (10 ans) et le certificat du Pi (825 jours).
#
#   certificats.sh <dossier> <utilisateur du service> [--redemarrer]
#
# Lancé par install.sh, puis chaque mois par le minuteur patiento-certificats.timer.
# Si le dossier contient un fichier « fourni », le certificat vient de l'établissement : rien n'est généré.
# L'autorité n'est créée qu'une fois : les postes qui lui font confiance n'ont rien à refaire.
# Le certificat du Pi est refait s'il expire dans moins de 60 jours ou si l'IP ou le nom du Pi change.
set -euo pipefail

DOSSIER="$1"
UTILISATEUR="$2"
REDEMARRER="${3:-}"
NOM="$(hostname -s)"
IPS="${PATIENTO_IPS:-$(hostname -I 2>/dev/null || true)}"

SAN="DNS:localhost,DNS:$NOM,DNS:$NOM.local,IP:127.0.0.1"
for ip in $IPS; do
  [[ "$ip" == *.* ]] && SAN="$SAN,IP:$ip"   # IPv4 uniquement
done

install -d -m 755 "$DOSSIER"
cd "$DOSSIER"

# Certificat fourni par l'établissement (install.sh --certificat) : on n'y touche pas.
if [[ -f fourni ]]; then
  if ! openssl x509 -in serveur.crt -noout -checkend $((30 * 86400)) >/dev/null; then
    echo "ATTENTION : le certificat fourni expire dans moins de 30 jours. Le remplacer avec install.sh --certificat." >&2
  fi
  exit 0
fi

if [[ ! -s ca.key || ! -s ca.crt ]]; then
  echo "Création de l'autorité de certification locale"
  openssl req -utf8 -x509 -newkey rsa:3072 -nodes -sha256 -days 3650 \
    -keyout ca.key -out ca.crt -subj "/CN=Patiento - autorité locale ($NOM)" \
    -addext "basicConstraints=critical,CA:TRUE,pathlen:0" \
    -addext "keyUsage=critical,keyCertSign,cRLSign" 2>/dev/null
  chmod 600 ca.key; chmod 644 ca.crt
  rm -f serveur.crt   # nouvelle autorité : refaire le certificat du Pi
fi

a_refaire=0
[[ -s serveur.key && -s serveur.crt ]] || a_refaire=1
[[ $a_refaire -eq 0 ]] && ! openssl x509 -in serveur.crt -noout -checkend $((60 * 86400)) >/dev/null && a_refaire=1
[[ $a_refaire -eq 0 && "$(cat serveur.san 2>/dev/null)" != "$SAN" ]] && a_refaire=1

if [[ $a_refaire -eq 1 ]]; then
  echo "Création du certificat du Pi ($SAN)"
  openssl req -utf8 -newkey rsa:2048 -nodes -sha256 -keyout serveur.key -out serveur.csr \
    -subj "/CN=$NOM" 2>/dev/null
  printf '%s\n' "basicConstraints=critical,CA:FALSE" "keyUsage=critical,digitalSignature,keyEncipherment" \
    "extendedKeyUsage=serverAuth" "subjectAltName=$SAN" > serveur.ext
  openssl x509 -req -in serveur.csr -CA ca.crt -CAkey ca.key -CAcreateserial -sha256 -days 825 \
    -extfile serveur.ext -out serveur.crt 2>/dev/null
  rm -f serveur.csr serveur.ext ca.srl
  echo "$SAN" > serveur.san
  chown "$UTILISATEUR" serveur.key; chmod 600 serveur.key; chmod 644 serveur.crt
  if [[ "$REDEMARRER" == --redemarrer ]] && systemctl is-active --quiet patiento; then
    systemctl restart patiento
  fi
fi
