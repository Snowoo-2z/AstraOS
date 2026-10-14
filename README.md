# AstraOS

**AstraOS** est un mini système d'exploitation x86 open source, développé *from scratch* pour apprendre comment un OS démarre vraiment.

Objectif du projet : un OS **léger en RAM**, noir/blanc, modulaire, avec une future couche **AstraAI** qui aide l'utilisateur sans alourdir le noyau.

Licence : **MIT**. Dépôt public : <https://github.com/Snowoo-2z/AstraOS>

---

## 🚀 Lancement en une ligne

### Tester cette branche Arena

Tant que la Pull Request n'est pas encore mergée dans `main`, utilise cette commande pour cloner et lancer **la branche de test** :

```bash
git clone --branch arena/01a10607-astraos --single-branch https://github.com/Snowoo-2z/AstraOS.git && cd AstraOS && sudo apt update && sudo apt install -y make nasm qemu-system-x86 && make run
```

Version WSL2 / SSH / environnement sans interface graphique :

```bash
git clone --branch arena/01a10607-astraos --single-branch https://github.com/Snowoo-2z/AstraOS.git && cd AstraOS && sudo apt update && sudo apt install -y make nasm qemu-system-x86 && make run-headless
```

### Après merge dans `main`

Sur Ubuntu / Debian avec interface graphique :

```bash
git clone https://github.com/Snowoo-2z/AstraOS.git && cd AstraOS && sudo apt update && sudo apt install -y make nasm qemu-system-x86 && make run
```

Sur WSL2 / SSH / environnement sans interface graphique :

```bash
git clone https://github.com/Snowoo-2z/AstraOS.git && cd AstraOS && sudo apt update && sudo apt install -y make nasm qemu-system-x86 && make run-headless
```

Si tu as déjà cloné le projet :

```bash
make run
```

Si tu es en SSH, WSL sans interface graphique, ou environnement headless :

```bash
make run-headless
```

---

## ✅ État actuel

AstraOS **0.1.0 Workspace** démarre maintenant avec :

- un **bootloader 16-bit** de 512 octets ;
- un passage en **32-bit protected mode** ;
- un mini **kernel 32-bit modulaire**, séparé en cœur, drivers, interface et données ;
- un écran texte VGA noir/blanc ;
- une sortie série pour le mode headless ;
- un clavier **FR AZERTY** par défaut, avec option US QWERTY ;
- un vrai flux clavier via **IRQ1** + buffer circulaire ;
- une **IDT** minimale avec handlers dédiés pour les 32 exceptions CPU ;
- un **PIC** remappé ;
- un timer **PIT 100 Hz** ;
- une boucle d'attente avec `HLT` pour éviter de brûler du CPU ;
- une détection mémoire BIOS **E820** ;
- une pagination 32-bit avec identity-map des premiers **4 MiB** ;
- un mini allocateur mémoire type **bump allocator** ;
- un mini système de fichiers RAM en lecture seule ;
- un premier **bureau graphique** monochrome avec barre des tâches et fenêtres ;
- un **menu Astra** avec Files, About et Reboot ;
- un compteur d'uptime dans la barre des tâches ;
- un **explorateur de fichiers** avec 8 fichiers RAM et souris absolue QEMU VMMouse ;
- un assistant `ai` local basé sur des règles ;
- des infos souris via IRQ12 ;
- des infos CPU via **CPUID** ;
- un petit shell interactif.

Commandes disponibles dans l'OS :

```txt
help
about
version
uptime
mem
mmap
paging
status
heap
alloc
cpu
irq
mouse
ls
explorer
files
explorateur
fichiers
gui
desktop
cat readme
echo hello
ai
ai mem
ai fichiers
kbd
kbd fr
kbd us
clear
reboot
```

La commande `ai` est volontairement une base légère pour l'instant : pas encore de vrai modèle IA, pour éviter de consommer beaucoup de RAM trop tôt. Elle commence maintenant à pointer vers les données noyau disponibles : `uptime`, `cpu`, `irq`, `mem`, `mmap`, `heap`.

### Clavier

Le clavier par défaut est maintenant **FR AZERTY**.

Dans AstraOS :

```txt
kbd       Affiche le layout actuel
kbd fr    Passe en AZERTY français
kbd us    Passe en QWERTY US
```

Côté QEMU graphique, `make run` lance aussi QEMU avec `-k fr` par défaut. Pour forcer un autre mapping QEMU côté hôte :

```bash
make run QEMU_KEYBOARD=en-us
```

### Timer, interruptions, mémoire

Le noyau installe maintenant une IDT, remappe le PIC, configure le PIT à environ 100 Hz, utilise IRQ1 pour le clavier et active une pagination identity-map des premiers 4 MiB.

Dans AstraOS :

```txt
uptime   Affiche le temps depuis le boot via le timer PIT
irq      Affiche les compteurs d'interruptions
mouse    Affiche l'état souris PS/2 / IRQ12
cpu      Affiche le vendor CPUID et les flags CPU
mem      Affiche RAM utilisable + état du heap
mmap     Affiche la carte mémoire BIOS E820
paging   Affiche CR0/CR3 + tables de pages
status   Résumé rapide du système
heap     Affiche l'allocateur mémoire minimal
alloc    Alloue un bloc de test de 256 octets
ls       Liste les fichiers RAM intégrés
explorer Ouvre le premier explorateur graphique
files    Alias de explorer
explorateur Alias FR de explorer
fichiers Alias FR de explorer
gui      Lance le bureau graphique
desktop  Lance le bureau graphique
cat NAME Affiche un fichier RAM
ai mem   Suggère des commandes selon un sujet
```

`alloc` n'est pas encore un malloc complet : c'est une première base de gestion mémoire, volontairement simple et prévisible.

### Premier bureau graphique

AstraOS possède maintenant un premier bureau VGA 320x200 avec une barre des tâches, un bouton Astra, des icônes et de petites fenêtres :

```txt
desktop
```

Les commandes `gui` et `desktop` ouvrent le bureau. Les commandes suivantes ouvrent directement le bureau avec la fenêtre Files :

```txt
explorer
files
explorateur
fichiers
```

Éléments disponibles sur le bureau :

- icône **FILES** : ouvre l'explorateur graphique ;
- icône **ABOUT** : ouvre les informations d'AstraOS ;
- bouton **ASTRA** : ouvre un menu avec Files, About et Reboot ;
- fenêtres déplaçables en maintenant le clic sur leur barre de titre ;
- bouton **X** : ferme la fenêtre active ;
- explorateur sur deux rangées avec `readme`, `roadmap`, `ai`, `license`, `system`, `commands`, `notes` et `credits` ;
- compteur d'uptime dans la barre des tâches monochrome.

Contrôles graphiques :

```txt
Souris      Déplacer le pointeur
Clic gauche Ouvrir une icône ou fermer une fenêtre
Clic + glisser Déplacer une fenêtre par sa barre de titre
e           Ouvrir la fenêtre Files
1 à 8       Ouvrir directement un fichier
Échap       Fermer la fenêtre active
c           Recentrer le curseur AstraOS
b / Entrée  Retour depuis le lecteur de fichier
q           Redémarrer pour revenir au shell texte
```

Tu peux vérifier la souris avec :

```txt
mouse
```

Dans QEMU, clique dans la fenêtre pour capturer la souris. Selon l'interface QEMU, `Ctrl` + `Alt` + `G` peut libérer la souris. Le mode graphique est visible avec `make run`; en `make run-headless`, la sortie reste surtout utile pour le shell série.

`make run` masque le curseur hôte QEMU avec `-display gtk,show-cursor=off`. AstraOS détecte maintenant le périphérique **VMMouse** fourni par QEMU et reçoit des coordonnées absolues : le curseur AstraOS suit directement la position de la souris Windows, même si la fenêtre QEMU est agrandie. Si VMMouse n'est pas disponible, le driver revient automatiquement au mode PS/2 relatif. Si ton QEMU ne supporte pas GTK, lance avec `make run QEMU_DISPLAY=`.

`make run` utilise aussi `-no-reboot -no-shutdown` pour garder la fenêtre ouverte si le noyau plante : ça aide à lire le message au lieu de voir QEMU disparaître.

Le rendu graphique utilise un backbuffer en RAM avant de copier l'image vers la VRAM, ce qui réduit fortement les effets de dessin blanc/flicker. La commande `mouse` indique `absolute VMMouse` lorsque la synchronisation hôte fonctionne. Si elle indique `relative PS/2 fallback`, AstraOS continue de fonctionner mais la position peut être moins naturelle.

Pour l'instant, le bureau et son mini gestionnaire de fenêtres sont dessinés directement par le kernel. L'explorateur parcourt le système de fichiers RAM intégré. VMMouse fournit les coordonnées absolues via le port hyperviseur, tandis que l'IRQ12 PS/2 signale les événements et reste disponible en secours. Le mode graphique reste volontairement léger : VGA mode 13h, fenêtres dessinées à la main et curseur logiciel. Les prochaines étapes seront la réduction/agrandissement des fenêtres, un vrai stockage disque et davantage d'applications.

---

## 🛠️ Prérequis manuels

Si tu ne veux pas utiliser la commande complète plus haut :

```bash
sudo apt update
sudo apt install -y make nasm qemu-system-x86
```

Puis :

```bash
make run
```

Tu peux vérifier les outils avec :

```bash
make doctor
```

---

## 📁 Structure du projet

```txt
boot/
  boot.asm              Bootloader BIOS 16-bit
kernel/
  kernel.asm            Point d'entrée et assemblage des modules
  include/config.inc    Constantes partagées
  core/                 Shell, mémoire et interruptions
  drivers/              Clavier, souris, série et affichage texte
  ui/                   Interface graphique et explorateur
  data.asm              Textes, tables, fontes et données globales
Makefile                 Build, image disque et lancement QEMU
LICENSE                  Licence MIT
README.md                Documentation du projet
ROADMAP.md               Grande liste de travail suivie
```

Le noyau produit reste un unique binaire léger : NASM assemble les modules avec `%include`. Les fichiers séparés rendent le projet plus lisible et facilitent les prochaines fonctions sans ajouter de coût en RAM.

---

## 🧠 Pourquoi 32-bit et pas directement 64-bit ?

Pour apprendre proprement, AstraOS démarre en 16-bit comme un PC x86 classique, puis passe en **32-bit protected mode**.

Le 64-bit viendra plus tard, car il demande d'ajouter :

- des tables de pages ;
- le long mode ;
- une initialisation CPU plus stricte ;
- une architecture mémoire plus solide.

Donc la base actuelle est volontairement simple, rapide et compréhensible.

---

## 🗺️ Roadmap

La grande liste de travail détaillée est dans [`ROADMAP.md`](ROADMAP.md). Elle couvre le bureau, le kernel, les pilotes, le stockage, le réseau, la sécurité, AstraAI et les tests.

### Phase 1 — Base bootable

- [x] Bootloader 512 octets
- [x] Image disque QEMU
- [x] Passage en 32-bit protected mode
- [x] Kernel texte minimal
- [x] Shell de base

### Phase 2 — Vrai noyau

- [x] IDT et interruptions
- [x] Timer système PIT 100 Hz
- [x] Pilote clavier par interruptions IRQ1
- [x] Détection mémoire BIOS/E820
- [x] Pagination 32-bit identity-map 4 MiB
- [x] Allocateur mémoire simple
- [x] Mini système de fichiers RAM intégré
- [x] Premier explorateur de fichiers texte
- [x] Souris PS/2 IRQ12 pour l'explorateur
- [x] Assistant local de commandes AstraAI
- [x] IDT avec handlers dédiés par exception
- [ ] Gestion mémoire plus complète

### Phase 3 — Stockage et fichiers

- [ ] Lecture disque plus robuste
- [x] Système de fichiers RAM minimal
- [x] Explorateur de fichiers RAM avec souris
- [ ] Système de fichiers disque minimal
- [ ] Chargement de fichiers/programmes

### Phase 4 — Sécurité et comptes

Les comptes utilisateurs ne sont **pas** la première étape. Il faudra d'abord avoir un système de fichiers, des permissions et une séparation kernel/userland.

- [ ] Mode utilisateur
- [ ] Processus
- [ ] Permissions
- [ ] Comptes

### Phase 5 — AstraAI

AstraAI doit rester hors du noyau pour garder l'OS fiable et léger.

Idées :

- assistant de commandes ;
- explication des erreurs ;
- suggestions système ;
- pont optionnel vers un modèle local ou distant ;
- aucun modèle lourd chargé par défaut.

---

## 🧹 Commandes utiles

Construire l'image :

```bash
make
```

Lancer dans QEMU :

```bash
make run
```

Lancer sans interface graphique :

```bash
make run-headless
```

Nettoyer :

```bash
make clean
```

---

## 🤝 Contribution

Le projet est open source. Les contributions sont bienvenues : idées, bugs, documentation, drivers, shell, mémoire, IA, etc.
