# Appel patients

Système d'appel des patients pour la salle d'attente : chaque praticien appelle son patient depuis son PC, la TV affiche « Mme Martin est attendue en salle 3 » avec un carillon et une annonce vocale. Entre deux appels, la TV montre un diaporama, les messages du cabinet et la liste des salles avec leur praticien.

Un seul programme Python, sans dépendance ni base de données, qui tourne sur un Raspberry Pi branché derrière la TV.

## Les pages

| Adresse | Pour qui | Rôle |
| --- | --- | --- |
| `/appel?salle=3` | Praticien | Appeler, rappeler ou annuler un appel pour sa salle |
| `/contenus` | Tous | Diaporama, messages, salles et praticiens, liens d'appel, réglages |
| `/ecran` | TV | Affichage de la salle d'attente |
| `/` | Tous | Accueil avec les liens vers les pages |

## Essayer sur un PC (prototype)

Il faut Python 3.9 ou plus récent.

```bash
python3 server.py
```

Puis ouvrir `http://localhost:8080/contenus` pour renseigner les salles, et `http://localhost:8080/ecran` dans une autre fenêtre (touche F11 pour le plein écran). Au premier lancement, cliquer une fois sur la page écran pour autoriser le son. Les appels se font depuis `http://localhost:8080/appel`.

La conversion des PowerPoint nécessite LibreOffice (`soffice`) et `pdftoppm` (paquet `poppler-utils`). Sans eux, l'appel et les messages fonctionnent, seul le dépôt de présentations échoue.

## Installer sur le Raspberry Pi

1. Installer Raspberry Pi OS **avec bureau** (Bookworm ou plus récent) et le relier au réseau par câble.
2. Demander au gestionnaire réseau une **IP fixe** pour le Pi (réservation DHCP sur l'adresse MAC).
3. Copier ce dossier sur le Pi, puis depuis le compte de session (par exemple `pi`) :

   ```bash
   cd appel-patients
   sudo ./installer/install.sh              # ou --avec-voix pour la voix Piper
   sudo reboot
   ```

Au redémarrage, la TV affiche directement l'écran de la salle d'attente. L'application écoute sur le port 80 : les praticiens utilisent `http://IP-DU-PI/appel?salle=N`.

L'option `--avec-voix` installe [Piper](https://github.com/OHF-Voice/piper1-gpl), une synthèse vocale hors ligne bien plus naturelle que la voix du navigateur. La voix est générée en mémoire, sans fichier sur le disque. Sans cette option, l'écran utilise la voix intégrée au navigateur.

### Réglages de la TV (Hisense 40A5S)

- Désactiver la **mise en veille automatique** (sinon la TV s'éteint après quelques heures sans télécommande).
- Activer le **HDMI-CEC** et, si le menu le propose, programmer l'allumage à 7 h 55 et l'extinction à 21 h. À défaut, l'écran passe au noir en dehors des horaires réglés dans la page Contenus.
- Laisser la TV **hors réseau** : seul le Pi est connecté.

## Confidentialité

- Les noms des patients restent **en mémoire vive** : jamais écrits sur disque ni dans les journaux, effacés de la liste après quelques minutes (5 par défaut) et à chaque redémarrage.
- Seuls la civilité et le nom de famille sont affichés, avec l'initiale du prénom en cas d'homonymes.
- Les pages ne sont accessibles que depuis le réseau du cabinet. Ne pas exposer le Pi sur Internet.

## Maintenance

| Besoin | Commande |
| --- | --- |
| État du service | `systemctl status appel-patients` |
| Journal | `journalctl -u appel-patients -e` |
| Redémarrer | `sudo systemctl restart appel-patients` |
| Mettre à jour | copier la nouvelle version puis relancer `sudo ./installer/install.sh` |
| Sauvegarder la configuration | copier `/var/lib/appel-patients/config.json` |

Le fichier `config.json` contient les salles, les messages et les réglages, jamais de nom de patient. Après installation, une image de la carte microSD permet de remettre le boîtier en service en quelques minutes.

## Dépannage

- **Pas de son sur le PC de test** : cliquer une fois sur l'écran (le navigateur bloque le son tant qu'on n'a pas interagi avec la page). Le kiosque du Pi est lancé avec l'option qui lève ce blocage.
- **Le PowerPoint s'affiche mal** : les polices absentes du Pi sont remplacées. Les polices Microsoft courantes (Calibri, Cambria) ont des équivalents installés ; sinon, exporter la présentation en PDF depuis PowerPoint et déposer le PDF.
- **« Connexion au serveur perdue » sur la TV** : vérifier que le service tourne ; l'écran se reconnecte tout seul.
