# AstraOS — grande feuille de route

Cette liste garde le développement concret, progressif et testable. Une case cochée doit correspondre à du code présent sur la branche active.

## Priorité actuelle — bureau utilisable

- [x] Démarrage BIOS 16-bit et noyau protégé 32-bit
- [x] Clavier AZERTY par défaut et IRQ1
- [x] Souris PS/2 IRQ12
- [x] Souris absolue QEMU VMMouse synchronisée avec l'hôte
- [x] Mode graphique VGA 320x200
- [x] Backbuffer pour limiter le scintillement
- [x] Premier bureau noir et blanc
- [x] Barre des tâches et bouton Astra
- [x] Fenêtres Files et About
- [x] Lecteur de fichiers graphique
- [x] Menu Astra avec raccourcis Files, About et Reboot
- [x] Horloge d'uptime dans la barre des tâches
- [x] Huit fichiers RAM visibles dans l'explorateur
- [x] Déplacement des fenêtres à la souris
- [x] Boutons réduire, restaurer et agrandir
- [ ] Focus et ordre d'empilement des fenêtres
- [ ] Retour au shell sans redémarrer
- [ ] Résolution graphique supérieure via VBE ou GOP

## Design Aurora

- [x] Palette VGA personnalisée noir, bleu et blanc
- [x] Écran de chargement graphique
- [x] Fond de bureau géométrique Astra
- [x] Cartes d'applications avec état de survol
- [x] Icônes distinctes Files, About, System et Notes
- [x] Fenêtres avec ombre, barre d'accent et contrôles colorés
- [x] Explorateur avec cartes de documents
- [x] Curseur logiciel avec contour et ombre
- [x] Rendu rapide du curseur par zone sale 12x13
- [x] Menu Astra et barre des tâches harmonisés
- [ ] Police bitmap plus grande avec minuscules et accents
- [ ] Animations d'ouverture et réduction
- [ ] Thèmes clair et sombre
- [ ] Framebuffer haute résolution

## Noyau

- [x] GDT et protected mode 32-bit
- [x] IDT avec handlers d'exceptions
- [x] PIC remappé
- [x] PIT à 100 Hz
- [x] Boucle idle avec HLT
- [x] Pagination des premiers 4 MiB
- [x] Détection mémoire BIOS E820
- [x] Allocateur bump minimal
- [x] Code séparé en modules core, drivers et UI
- [ ] Allocateur de pages physiques
- [ ] Heap avec libération des blocs
- [ ] Mapping mémoire dynamique
- [ ] Ring 3 et séparation utilisateur/noyau
- [ ] Appels système
- [ ] Processus et ordonnanceur préemptif
- [ ] Threads
- [ ] Verrous et primitives de synchronisation
- [ ] Passage x86_64 long mode

## Stockage et fichiers

- [x] RAMFS en lecture seule
- [x] Commandes ls et cat
- [x] Explorateur texte
- [x] Explorateur graphique
- [ ] Table de fichiers RAM centralisée
- [ ] Création et modification de fichiers RAM
- [ ] Pilote ATA PIO
- [ ] Lecture d'une partition disque
- [ ] FAT12 pour l'image disquette
- [ ] FAT32 pour un disque moderne
- [ ] Dossiers et chemins
- [ ] Copier, déplacer, renommer et supprimer
- [ ] Éditeur de texte
- [ ] Sauvegarde persistante

## Pilotes

- [x] VGA texte
- [x] VGA mode 13h
- [x] Série COM1
- [x] Clavier PS/2
- [x] Souris PS/2
- [x] VMMouse absolue
- [ ] RTC pour date et heure réelles
- [ ] PCI : énumération des périphériques
- [ ] ACPI : extinction propre
- [ ] VBE framebuffer
- [ ] Son PC speaker
- [ ] Audio AC97 ou Intel HDA
- [ ] Réseau RTL8139 ou virtio-net
- [ ] USB UHCI/EHCI/xHCI
- [ ] Tablette USB absolue hors QEMU PC

## Interface et applications

- [x] Shell interactif
- [x] Bureau graphique
- [x] Explorateur Files
- [x] Fenêtre About
- [ ] Menu Astra
- [ ] Terminal graphique
- [x] Bloc-notes RAM graphique minimal
- [ ] Calculatrice
- [x] Moniteur système graphique en direct
- [ ] Paramètres clavier et souris
- [ ] Sélecteur de thème
- [ ] Notifications
- [ ] Gestionnaire d'applications
- [ ] API graphique commune pour les applications

## Réseau et sécurité

- [ ] Adresse MAC et pilote réseau
- [ ] Ethernet
- [ ] ARP
- [ ] IPv4
- [ ] ICMP ping
- [ ] UDP
- [ ] DHCP
- [ ] DNS
- [ ] TCP minimal
- [ ] Permissions de fichiers
- [ ] Comptes utilisateurs
- [ ] Isolation des processus
- [ ] Journal des événements système

## AstraAI

- [x] Assistant local léger basé sur des règles
- [x] Conseils sur mémoire, CPU, IRQ, clavier et fichiers
- [ ] Interface graphique AstraAI
- [ ] Historique local des commandes
- [ ] Recherche dans l'aide et les fichiers
- [ ] Actions système confirmées par l'utilisateur
- [ ] API permettant de brancher un modèle externe
- [ ] Petit moteur local optionnel en espace utilisateur
- [ ] Aucun modèle lourd dans le noyau

## Qualité et distribution

- [x] Licence MIT
- [x] Dépôt GitHub public
- [x] Build en une commande avec Make
- [x] Exécution graphique et headless
- [x] Vérification de taille du kernel
- [ ] Build CI automatique NASM
- [ ] Tests automatisés du boot série
- [ ] Image disque versionnée
- [ ] Releases GitHub téléchargeables
- [ ] Documentation développeur par module
- [ ] Guide de contribution
- [ ] Capture d'écran et vidéo de démonstration

## Règle de développement

1. Garder le noyau léger et compréhensible.
2. Préférer une petite fonction testable à une grosse fonctionnalité fragile.
3. Conserver un mode de secours lorsqu'un pilote avancé n'est pas disponible.
4. Tester le boot après chaque changement bas niveau.
5. Ne pas placer un modèle IA lourd dans le kernel.
