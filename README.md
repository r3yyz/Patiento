# Patiento

Système d'appel des patients pour la salle d'attente d'un cabinet. Chaque praticien appelle son patient depuis son PC ou son smartphone ; la TV de la salle d'attente affiche « Mme Martin est attendue en salle 3 », joue un carillon et fait une annonce vocale. Entre deux appels, la TV montre un diaporama, les messages du cabinet et la liste des salles avec leur praticien.

Tout tient dans **un seul programme Python**, sans dépendance externe ni base de données, qui tourne sur un Raspberry Pi branché derrière la TV.

## Sommaire

- [Fonctionnement](#fonctionnement)
- [Les pages](#les-pages)
- [Contenu du dépôt](#contenu-du-dépôt)
- [Essayer sur un PC](#essayer-sur-un-pc)
- [Installer sur le Raspberry Pi](#installer-sur-le-raspberry-pi)
- [Première configuration](#première-configuration)
- [Utilisation au quotidien](#utilisation-au-quotidien)
- [Confidentialité](#confidentialité)
- [Maintenance](#maintenance)
- [Réglages avancés](#réglages-avancés)
- [Dépannage](#dépannage)

## Fonctionnement

```
 PC / smartphone du praticien              Raspberry Pi                    TV (HDMI)
┌──────────────────────────┐        ┌──────────────────────┐        ┌──────────────────┐
│ http://IP-DU-PI/appel    │ appel  │  server.py           │ temps  │ Chromium (kiosque)│
│ ?salle=3                 ├───────▶│  - appels en mémoire │ réel   │ /ecran            │
│ « Mme Martin »  [Appeler]│  HTTP  │  - config.json       ├───────▶│ carillon + voix   │
└──────────────────────────┘        │  - voix (option)     │  SSE   │ diaporama, messages│
                                    └──────────────────────┘        └──────────────────┘
```

1. Le praticien ouvre la page d'appel de **sa salle**, choisit M. ou Mme, saisit le nom de famille (et, en cas d'homonymes, l'initiale du prénom), puis clique sur **Appeler**.
2. Le serveur enregistre l'appel **en mémoire vive uniquement** et prévient immédiatement l'écran par un flux d'événements (`/evenements`, Server-Sent Events). Il n'y a pas d'actualisation périodique : l'affichage est instantané.
3. L'écran de la salle d'attente affiche la phrase en plein écran pendant la durée réglée (25 s par défaut), joue le carillon et lit l'annonce à voix haute.
4. L'appel reste ensuite dans la liste des derniers appels (5 minutes par défaut), puis disparaît. Le praticien peut **rappeler** (l'annonce est rejouée) ou **annuler** un appel.
5. Sans appel en cours, l'écran alterne le diaporama et les messages du cabinet, avec la liste des salles et des praticiens et l'horloge. En dehors des horaires réglés, l'écran passe au noir.

Les salles, les praticiens, les messages, le diaporama et les réglages sont enregistrés dans `config.json`. Aucun nom de patient n'y figure jamais.

### Annonce vocale

Deux modes, au choix à l'installation :

- **Voix du navigateur** (par défaut) : l'écran utilise la synthèse vocale intégrée à Chromium.
- **Voix Piper** (`--avec-voix`) : synthèse vocale française hors ligne, plus naturelle. La voix est générée en mémoire, sans fichier sur le disque, et envoyée à l'écran via `/api/voix/<id>`.

### Diaporama

Les présentations PowerPoint (`.pptx`, `.ppt`, `.ppsx`, `.pps`), OpenDocument (`.odp`) et les PDF sont déposés depuis la page **Contenus** (200 Mo maximum). Le serveur les convertit en images avec LibreOffice et `pdftoppm`, puis l'écran les fait défiler. Les images `.png` et `.jpg` sont aussi acceptées. Un seul diaporama est actif à la fois, et une seule conversion peut tourner à la fois.

## Les pages

| Adresse | Pour qui | Rôle |
| --- | --- | --- |
| `/appel?salle=3` | Praticien | Appeler, rappeler ou annuler un appel pour sa salle |
| `/contenus` | Secrétariat, gestionnaire | Diaporama, messages, salles et praticiens, liens d'appel, réglages |
| `/ecran` | TV | Affichage de la salle d'attente |
| `/` | Tous | Accueil avec les liens vers les pages |

## Contenu du dépôt

```
Patiento/
├── server.py            serveur HTTP (bibliothèque standard Python uniquement)
├── static/              pages et ressources web (accueil, appel, contenus, écran)
├── installer/install.sh installation complète sur Raspberry Pi
├── data/config.json     configuration utilisée pour les essais sur PC
└── README.md
```

## Essayer sur un PC

Il faut Python 3.9 ou plus récent.

```bash
python3 server.py
```

Puis :

- ouvrir `http://localhost:8080/contenus` pour renseigner les salles ;
- ouvrir `http://localhost:8080/ecran` dans une autre fenêtre (touche F11 pour le plein écran) ;
- cliquer une fois sur la page écran pour autoriser le son ;
- faire les appels depuis `http://localhost:8080/appel`.

La conversion des présentations nécessite LibreOffice (`soffice`) et `pdftoppm` (paquet `poppler-utils`). Sans eux, les appels et les messages fonctionnent, seul le dépôt de présentations échoue.

En mode essai, les données sont stockées dans le dossier `data/` du projet.

## Installer sur le Raspberry Pi

### Matériel et prérequis

- Un Raspberry Pi relié à la TV en HDMI et au réseau du cabinet **par câble**.
- Raspberry Pi OS **avec bureau**, version Bookworm ou plus récente.
- Une **IP fixe** pour le Pi : demander au gestionnaire réseau une réservation DHCP sur l'adresse MAC.
- Un accès à Internet pendant l'installation (paquets, et voix Piper si l'option est choisie).

### Installation

1. Copier ce dossier sur le Pi, ou le cloner :

   ```bash
   git clone https://github.com/r3yyz/Patiento.git
   ```

2. Depuis le compte qui ouvre la session du bureau (par exemple `pi`), lancer le script avec `sudo` :

   ```bash
   cd Patiento
   sudo ./installer/install.sh              # ou : sudo ./installer/install.sh --avec-voix
   sudo reboot
   ```

Au redémarrage, la TV affiche directement l'écran de la salle d'attente. L'application écoute sur le port 80 : les praticiens utilisent `http://IP-DU-PI/appel?salle=N`.

### Ce que fait le script

| Étape | Détail |
| --- | --- |
| Paquets | Python 3, LibreOffice Impress, poppler-utils, polices, Chromium |
| Application | copiée dans `/opt/patiento`, données dans `/var/lib/patiento` |
| Service | utilisateur système dédié `appel`, service systemd `patiento` démarré au boot et relancé en cas de plantage, avec des protections systemd (système en lecture seule, pas d'accès aux dossiers personnels) |
| Voix (option) | environnement Python dédié, Piper et la voix `fr_FR-siwis-medium` dans `/opt/patiento/voix` |
| Écran | Chromium en mode kiosque lancé au démarrage du bureau (`/usr/local/bin/appel-kiosque`), ouverture automatique de session et mise en veille de l'écran désactivées |

Relancer le script met l'application à jour **sans toucher aux données**.

### Réglages de la TV (Hisense 40A5S)

- Désactiver la **mise en veille automatique** (sinon la TV s'éteint après quelques heures sans télécommande).
- Activer le **HDMI-CEC** et, si le menu le propose, programmer l'allumage à 7 h 55 et l'extinction à 21 h. À défaut, l'écran passe au noir en dehors des horaires réglés dans la page Contenus.
- Laisser la TV **hors réseau** : seul le Pi est connecté.

## Première configuration

Depuis n'importe quel PC du cabinet, ouvrir `http://IP-DU-PI/contenus` :

1. **Réglages** : saisir le nom affiché en haut de l'écran, la durée d'un appel, la durée par diapositive, la durée de visibilité des derniers appels et les horaires d'allumage de l'écran.
2. **Salles et praticiens** : indiquer le numéro de chaque salle et le praticien associé (le bouton « Ajouter une salle » en crée d'autres). Enregistrer.
3. **Liens d'appel des praticiens** : chaque praticien met en favori le lien de sa salle, ou télécharge le **raccourci bureau** (`.url`) et le place sur son bureau.
4. **Messages** (facultatif) : ajouter un texte et, si besoin, une date de fin (« Jusqu'au »). Le message n'est plus affiché sur l'écran après cette date.
5. **Diaporama** (facultatif) : déposer une présentation PowerPoint, un PDF ou des images.

Le bouton « Voir l'écran » ouvre l'affichage de la salle d'attente pour contrôler le résultat.

## Utilisation au quotidien

**Praticien** : ouvrir la page de sa salle, choisir la civilité, saisir le nom de famille, cliquer sur **Appeler**. En cas de patients homonymes, renseigner l'initiale du prénom. Les boutons de la liste permettent de rappeler ou d'annuler un appel. Un même patient appelé deux fois dans la même salle n'apparaît qu'une fois.

**Secrétariat** : la page `/contenus` sert à changer un message, remplacer le diaporama ou modifier le praticien d'une salle, sans toucher à l'installation.

**TV** : rien à faire. Elle s'allume, affiche l'écran et se reconnecte toute seule si le service redémarre.

## Confidentialité

- Les noms des patients restent **en mémoire vive** : jamais écrits sur disque ni dans les journaux, effacés de la liste après quelques minutes (5 par défaut) et à chaque redémarrage.
- Seuls la civilité et le nom de famille sont affichés, avec l'initiale du prénom en cas d'homonymes.
- Les pages ne sont accessibles que depuis le réseau du cabinet. **Ne pas exposer le Pi sur Internet.**
- Les pages n'ont pas d'authentification : toute personne connectée au réseau du cabinet peut appeler un patient ou modifier les contenus. Réserver ce réseau au personnel.

## Maintenance

| Besoin | Commande |
| --- | --- |
| État du service | `systemctl status patiento` |
| Journal | `journalctl -u patiento -e` |
| Redémarrer | `sudo systemctl restart patiento` |
| Mettre à jour | récupérer la nouvelle version (`git pull`) puis relancer `sudo ./installer/install.sh` |
| Sauvegarder la configuration | copier `/var/lib/patiento/config.json` (et le dossier `/var/lib/patiento/diapos` pour le diaporama) |

Après installation, une image de la carte microSD permet de remettre le boîtier en service en quelques minutes.

### Désinstaller

```bash
sudo systemctl disable --now patiento
sudo rm /etc/systemd/system/patiento.service /usr/local/bin/appel-kiosque
sudo rm -r /opt/patiento                      # application
sudo rm -r /var/lib/patiento                  # données (config, diaporama) : à sauvegarder avant
rm ~/.config/autostart/appel-kiosque.desktop  # démarrage de l'écran kiosque
```

## Réglages avancés

Le serveur se configure par variables d'environnement (le script d'installation les renseigne dans le service systemd) :

| Variable | Rôle | Défaut |
| --- | --- | --- |
| `APPEL_PORT` | port d'écoute | `8080` (le script d'installation utilise `80`) |
| `APPEL_HOST` | adresse d'écoute | `0.0.0.0` |
| `APPEL_DATA` | dossier des données | `./data` (`/var/lib/patiento` après installation) |
| `APPEL_TTS_MODEL` | chemin d'une voix Piper (`.onnx`) | vide : voix du navigateur |

Pour installer sur un autre port : `sudo APPEL_PORT=8080 ./installer/install.sh`. Avec `sudo`, vérifier que la variable est bien transmise (`sudo --preserve-env=APPEL_PORT` si nécessaire).

## Dépannage

- **Pas de son sur le PC de test** : cliquer une fois sur l'écran (le navigateur bloque le son tant qu'on n'a pas interagi avec la page). Le kiosque du Pi est lancé avec l'option qui lève ce blocage.
- **Le PowerPoint s'affiche mal** : les polices absentes du Pi sont remplacées. Les polices Microsoft courantes (Calibri, Cambria) ont des équivalents installés ; sinon, exporter la présentation en PDF depuis PowerPoint et déposer le PDF.
- **« Connexion au serveur perdue » sur la TV** : vérifier que le service tourne (`systemctl status patiento`) ; l'écran se reconnecte tout seul.
- **L'écran reste noir** : vérifier les horaires dans `/contenus` (l'écran passe au noir en dehors de la plage réglée) et l'heure du Pi.
- **Page inaccessible depuis un PC** : vérifier que le PC est sur le même réseau que le Pi et que l'IP du Pi n'a pas changé (réservation DHCP).
