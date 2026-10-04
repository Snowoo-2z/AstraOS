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

AstraOS **0.0.6 Pointer** démarre maintenant avec :

- un **bootloader 16-bit** de 512 octets ;
- un passage en **32-bit protected mode** ;
- un mini **kernel 32-bit** ;
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
- un premier **explorateur de fichiers** interactif avec pointeur souris PS/2 ;
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
gui      Lance l interface graphique
desktop  Alias de gui
cat NAME Affiche un fichier RAM
ai mem   Suggère des commandes selon un sujet
```

`alloc` n'est pas encore un malloc complet : c'est une première base de gestion mémoire, volontairement simple et prévisible.

### Explorateur de fichiers

AstraOS possède maintenant une première interface graphique VGA 320x200 centrée sur l explorateur de fichiers :

```txt
explorer
```

Alias :

```txt
files
explorateur
fichiers
```

Contrôles dans l'explorateur :

```txt
Souris      Déplacer le pointeur
Clic gauche Ouvrir le fichier sous le pointeur
z / k       Monter
s / j       Descendre
Entrée / o  Ouvrir le fichier sélectionné
b / Entrée  Retour depuis un fichier
q           Redémarrer pour revenir au shell texte
```

Tu peux vérifier la souris avec :

```txt
mouse
```

Dans QEMU, clique dans la fenêtre pour capturer la souris. Selon l'interface QEMU, `Ctrl` + `Alt` + `G` peut libérer la souris. Le mode graphique est visible avec `make run`; en `make run-headless`, la sortie reste surtout utile pour le shell série.

`make run` utilise aussi `-no-reboot -no-shutdown` pour garder la fenêtre ouverte si le noyau plante : ça aide à lire le message au lieu de voir QEMU disparaître.

Pour l'instant, il explore le système de fichiers RAM intégré au kernel. La souris est une première implémentation PS/2 en IRQ12. Le mode graphique est encore volontairement simple : VGA mode 13h, fenêtres dessinées à la main, curseur logiciel. La prochaine étape sera un vrai stockage disque et une interface graphique plus complète.

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
  boot.asm       Bootloader x86 16-bit, charge le kernel et passe en protected mode
kernel/
  kernel.asm     Kernel 32-bit minimal + shell
Makefile         Build, image disque, lancement QEMU
LICENSE          Licence MIT
README.md        Documentation du projet
```

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
