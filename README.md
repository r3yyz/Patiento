# Patiento

Système d'appel des patients pour la salle d'attente d'une maison de santé. Il est conçu pour la [maison de santé pluriprofessionnelle de Lamotte-Beuvron](https://www.coeurdesologne.com/jentreprends/chercher-un-local/la-maison-de-sante-pluriprofessionnelle/) (pôles médecine, dentaire, kinésithérapie et infirmiers) et reste adaptable à tout autre cabinet ou structure. Chaque praticien appelle son patient depuis son PC ou son smartphone ; la TV de la salle d'attente affiche « Mme Martin est attendue en salle 3 », joue un carillon et fait une annonce vocale. Entre deux appels, la TV montre un diaporama, les messages de la maison de santé et la liste des salles regroupées par pôle, avec leur praticien.

Tout tient dans **un seul programme Python**, sans dépendance externe ni base de données, qui tourne sur un Raspberry Pi branché derrière la TV.

## Sommaire

- [Fonctionnement](#fonctionnement)
- [Les pages](#les-pages)
- [Contenu du dépôt](#contenu-du-dépôt)
- [Essayer sur un PC](#essayer-sur-un-pc)
- [Installer sur le Raspberry Pi](#installer-sur-le-raspberry-pi)
- [Première configuration](#première-configuration)
- [Adapter Patiento à une autre structure](#adapter-patiento-à-une-autre-structure)
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
5. Sans appel en cours, l'écran alterne le diaporama et les messages de la maison de santé, avec la liste des salles et des praticiens, regroupés par pôle, et l'horloge. En dehors des horaires réglés, l'écran passe au noir.

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
│   └── polices/         police Atkinson Hyperlegible Next, servie en local (licence OFL)
├── installer/install.sh installation complète sur Raspberry Pi
├── data/config.example.json   exemple de configuration (noms fictifs)
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

En mode essai, les données sont stockées dans le dossier `data/` du projet. Sans fichier `data/config.json`, le serveur démarre avec la structure de la maison de santé (12 salles réparties en 4 pôles, sans nom de praticien). Pour partir d'un exemple rempli avec des noms fictifs :

```bash
cp data/config.example.json data/config.json
```

Le fichier `data/config.json`, le diaporama et tout le reste de `data/` ne sont **pas versionnés** (voir `.gitignore`) : la configuration réelle ne part jamais sur GitHub. Seul `config.example.json` est publié.

## Installer sur le Raspberry Pi

### Matériel et prérequis

- Un Raspberry Pi relié à la TV en HDMI et au réseau de la maison de santé **par câble**.
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

Depuis n'importe quel PC de la maison de santé, ouvrir `http://IP-DU-PI/contenus` :

1. **Réglages** : saisir le nom affiché en haut de l'écran, la durée d'un appel, la durée par diapositive, la durée de visibilité des derniers appels et les horaires d'allumage de l'écran.
2. **Salles, pôles et praticiens** : pour chaque salle, indiquer le numéro, le pôle (Médecine, Dentaire, Kinésithérapie, Infirmiers) et le praticien (le bouton « Ajouter une salle » en crée d'autres). Les salles proposées par défaut (6 cabinets de généralistes et 1 de spécialistes, 2 dentaire, 2 kinésithérapie, 1 infirmiers) sont une base à ajuster au bâtiment réel. Une salle sans nom de praticien n'est pas affichée en bas de l'écran. Enregistrer.
3. **Liens d'appel des praticiens** : chaque praticien met en favori le lien de sa salle, ou télécharge le **raccourci bureau** (`.url`) et le place sur son bureau.
4. **Messages** (facultatif) : ajouter un texte et, si besoin, une date de fin (« Jusqu'au »). Le message n'est plus affiché sur l'écran après cette date.
5. **Diaporama** (facultatif) : déposer une présentation PowerPoint, un PDF ou des images.

Le bouton « Voir l'écran » ouvre l'affichage de la salle d'attente pour contrôler le résultat.

## Adapter Patiento à une autre structure

Patiento est réglé pour la maison de santé de Lamotte-Beuvron, mais rien n'est figé. Ce tableau récapitule tout ce qui peut changer d'un cabinet à l'autre, et où le modifier.

| Ce qui change | Où le modifier | Faut-il redémarrer ? |
| --- | --- | --- |
| Nom affiché en haut de l'écran | page Contenus › Réglages | non |
| Nombre de salles, numéros, pôles, praticiens | page Contenus › Salles | non |
| Durée d'un appel, d'une diapositive, des derniers appels | page Contenus › Réglages | non |
| Horaires d'allumage de l'écran | page Contenus › Réglages | non |
| Messages et diaporama | page Contenus | non |
| Configuration de départ d'une nouvelle installation | `data/config.example.json` ou `DEFAULT_CONFIG` dans `server.py` | avant le premier démarrage |
| Port, adresse d'écoute, dossier des données | variables d'environnement (voir [Réglages avancés](#réglages-avancés)) | oui |
| Voix de l'annonce | option `--avec-voix` et variables `VOIX_NOM` / `VOIX_URL` de `installer/install.sh` | oui (relancer le script) |
| Couleurs | variables du `:root` dans `static/commun.css` (pages PC) et `static/ecran.html` (TV) | non (recharger les pages) |
| Volume | télécommande de la TV | non |

### Les salles

Une « salle » est un lieu où l'on appelle un patient : un cabinet de consultation, un box, une salle de soins. Dans la page Contenus, section **Salles, pôles et praticiens** :

- **Ajouter une salle** : bouton « + Ajouter une salle », remplir la ligne, puis **Enregistrer les salles**.
- **Retirer une salle** : bouton « Retirer » sur la ligne, puis **Enregistrer les salles**. Il faut garder au moins une salle.
- **Numéro** : texte libre de 10 caractères au maximum. Des chiffres (`3`), une lettre (`B`) ou un mot court (`Soins`) conviennent : l'écran affichera « est attendue en salle B ». Chaque numéro doit être unique.
- **Pôle** : texte libre de 40 caractères au maximum (« Médecine », « Podologie », « Sages-femmes »…). Les salles d'un même pôle sont regroupées en bas de l'écran **dans l'ordre de la liste** : garder les salles d'un même pôle à la suite. Pour un cabinet sans pôles (par exemple 5 kinésithérapeutes), laisser le champ vide : les salles s'affichent simplement les unes après les autres.
- **Praticien** : 60 caractères au maximum (« Dr Dupont », « Cabinet infirmier »). Laisser vide pour masquer la salle en bas de l'écran ; on peut toujours y appeler un patient.

> **Attention aux liens des praticiens.** Le lien d'appel contient le numéro de salle (`/appel?salle=3`). Si on renumérote ou retire une salle, l'ancien lien affiche « La salle 3 n'existe pas » : redonner au praticien son nouveau lien ou son nouveau raccourci (section **Liens d'appel des praticiens**). Changer seulement le nom du praticien ne casse pas le lien.

Exemples :

| Structure | Salles à saisir |
| --- | --- |
| Cabinet de kinésithérapie, 5 praticiens | salles `1` à `5`, pôle vide, un kinésithérapeute par salle |
| Cabinet médical, 3 médecins et 1 infirmière | salles `1` à `3` en « Médecine », salle `Soins` en « Infirmiers » |
| Maison de santé (configuration par défaut) | salles `1` à `7` en « Médecine », `8` et `9` en « Dentaire », `10` et `11` en « Kinésithérapie », `12` en « Infirmiers » |

### Préparer la configuration avant l'installation

Pour déployer dans une autre structure sans tout ressaisir sur place :

1. Copier `data/config.example.json` dans `data/config.json` et l'éditer : nom (`cabinet`), salles, durées, horaires. Les durées sont bornées : `duree_appel` de 5 à 120 s, `duree_diapo` de 3 à 120 s, `duree_historique` de 1 à 30 min ; `horaires` au format `HH:MM`.
2. Installer le Pi normalement, puis copier ce fichier dans `/var/lib/patiento/config.json` et redémarrer le service :

   ```bash
   sudo cp data/config.json /var/lib/patiento/config.json
   sudo chown appel:appel /var/lib/patiento/config.json
   sudo systemctl restart patiento
   ```

Pour modifier `config.json` à la main sur un Pi en service, **arrêter le service avant** (`sudo systemctl stop patiento`), sinon le serveur réécrit le fichier à la prochaine modification faite depuis la page Contenus. Un champ absent du fichier reprend sa valeur par défaut.

Pour changer la configuration de départ de toutes les futures installations (sans `config.json`), modifier `DEFAULT_CONFIG` en haut de `server.py`.

### Couleurs, voix et son

- **Couleurs** : toutes les couleurs sont des variables CSS en tête de `static/commun.css` (`--accent`, `--fond`, `--encre`…) et de `static/ecran.html` (`--nuit`, `--accent`, `--accent-vif`…). Changer ces valeurs suffit. Vérifier le contraste du texte sur la TV, qui doit rester lisible à plusieurs mètres.
- **Voix** : sans l'option `--avec-voix`, l'annonce utilise la voix du navigateur. Avec l'option, le script installe la voix Piper `fr_FR-siwis-medium` ; une autre voix française du [catalogue Piper](https://huggingface.co/rhasspy/piper-voices/tree/main/fr/fr_FR) s'utilise en changeant `VOIX_NOM` et `VOIX_URL` en tête de `installer/install.sh`, puis en relançant le script.
- **Son** : le volume se règle sur la TV. Le carillon est généré dans `static/ecran.html` (fonction `carillon`).

## Utilisation au quotidien

**Praticien** : ouvrir la page de sa salle, choisir la civilité, saisir le nom de famille, cliquer sur **Appeler**. En cas de patients homonymes, renseigner l'initiale du prénom. Les boutons de la liste permettent de rappeler ou d'annuler un appel. Un même patient appelé deux fois dans la même salle n'apparaît qu'une fois.

**Secrétariat** : la page `/contenus` sert à changer un message, remplacer le diaporama ou modifier le praticien d'une salle, sans toucher à l'installation.

**TV** : rien à faire. Elle s'allume, affiche l'écran et se reconnecte toute seule si le service redémarre.

## Confidentialité

- Les noms des patients restent **en mémoire vive** : jamais écrits sur disque ni dans les journaux, effacés de la liste après quelques minutes (5 par défaut) et à chaque redémarrage.
- Seuls la civilité et le nom de famille sont affichés, avec l'initiale du prénom en cas d'homonymes.
- Les pages ne sont accessibles que depuis le réseau de la maison de santé. **Ne pas exposer le Pi sur Internet.**
- Les pages n'ont pas d'authentification : toute personne connectée au réseau de la maison de santé peut appeler un patient ou modifier les contenus. Réserver ce réseau au personnel.

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
