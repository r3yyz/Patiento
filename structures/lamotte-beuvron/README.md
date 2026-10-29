# Déploiement : maison de santé de Lamotte-Beuvron

Fiche de déploiement propre à la [maison de santé pluriprofessionnelle de Lamotte-Beuvron](https://www.coeurdesologne.com/jentreprends/chercher-un-local/la-maison-de-sante-pluriprofessionnelle/). **Ce dossier reste dans le dépôt privé** : il n'est jamais publié dans `patiento-app`.

Le fonctionnement général, l'installation et la maintenance sont décrits dans le [README principal](../../README.md).

## La structure

- Maison de santé pluriprofessionnelle, quatre pôles : **médecine, dentaire, kinésithérapie, infirmiers**.
- Projet né pour un cabinet de kinésithérapie de 5 praticiens, puis étendu à toute la maison de santé.
- Logiciel métier : **Kiné+4000** (Cegedim). Aucune intégration : la saisie du nom est manuelle.
- Horaires d'ouverture : **8 h à 21 h**.

## Configuration

Fichier : [`config.json`](config.json). Il ne contient aucun nom de praticien ni de patient : les praticiens se saisissent sur place, dans la page Contenus.

| Réglage | Valeur |
| --- | --- |
| Nom affiché | Maison de santé de Lamotte-Beuvron |
| Salles 1 à 7 | Médecine (6 généralistes et 1 spécialiste) |
| Salles 8 et 9 | Dentaire |
| Salles 10 et 11 | Kinésithérapie |
| Salle 12 | Infirmiers |
| Durée d'un appel | 25 s |
| Durée par diapositive | 10 s |
| Derniers appels visibles | 5 min |
| Écran allumé | de 08:00 à 21:00 |

La répartition des salles est une base : **à ajuster au plan réel du bâtiment** avant la mise en service.

## Matériel

| Élément | Choix |
| --- | --- |
| Ordinateur | Raspberry Pi 5, 4 Go, Raspberry Pi OS avec bureau |
| Réseau | câble Ethernet, IP fixe par réservation DHCP auprès du gestionnaire réseau |
| TV | **Hisense 40A5S** (40", Full HD, VIDAA, HDMI-CEC), fixée en hauteur sur un mur visible de toute la salle, support inclinable |
| Son | haut-parleurs de la TV, par le HDMI |

### Réglages de la Hisense 40A5S

- Désactiver la **mise en veille automatique** (sinon la TV s'éteint après quelques heures sans télécommande).
- Activer le **HDMI-CEC** et, si le menu le propose, programmer l'allumage à **7 h 55** et l'extinction à **21 h**.
- Laisser la TV **hors réseau** : seul le Pi est connecté.

## Mise en service

```bash
git clone https://github.com/r3yyz/Patiento.git    # dépôt privé
cd Patiento
sudo ./installer/install.sh --avec-voix
sudo cp structures/lamotte-beuvron/config.json /var/lib/patiento/config.json
sudo chown appel:appel /var/lib/patiento/config.json
sudo systemctl restart patiento
sudo reboot
```

Puis, depuis un poste de la maison de santé, ouvrir `http://IP-DU-PI/contenus` pour saisir les praticiens et distribuer les liens d'appel.

Connexion sécurisée : la maison de santé n'a pas d'autorité de certification ni de domaine Windows, donc on garde l'**autorité locale autosignée** (mode par défaut). Postes principalement en **Wi-Fi**, indépendants : chaque poste et smartphone est guidé à sa première connexion pour installer le certificat (sans droits administrateur sous Windows). Noter l'empreinte affichée à la fin de l'installation pour la comparer sur les postes.

## Points restant ouverts

- [ ] Vérifier qu'il y a une prise électrique et une prise réseau à hauteur de la TV (sinon, prévoir une goulotte).
- [ ] Désactiver la mise en veille de la Hisense et tester l'allumage programmé.
- [ ] Essai sur place : lisibilité depuis le fond de la salle, carillon, volume, voix.
- [ ] Vérifier la gêne éventuelle de l'encart « Derniers appels » sur les diapositives.
- [ ] Ajuster les salles au plan réel du bâtiment.
- [ ] Vérifier sur le Pi le minuteur `patiento-certificats.timer` et l'écoute sur les ports 80 et 443.
- [ ] Équiper un premier poste Windows et un smartphone avec le guide, et corriger un libellé si un menu diffère.
