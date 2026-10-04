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

AstraOS **0.0.2 Pulse** démarre maintenant avec :

- un **bootloader 16-bit** de 512 octets ;
- un passage en **32-bit protected mode** ;
- un mini **kernel 32-bit** ;
- un écran texte VGA noir/blanc ;
- une sortie série pour le mode headless ;
- un clavier **FR AZERTY** par défaut, avec option US QWERTY ;
- une **IDT** minimale ;
- un **PIC** remappé ;
- un timer **PIT 100 Hz** ;
- une boucle d'attente avec `HLT` pour éviter de brûler du CPU ;
- un petit shell interactif.

Commandes disponibles dans l'OS :

```txt
help
about
version
uptime
mem
ai
kbd
kbd fr
kbd us
clear
reboot
```

La commande `ai` est volontairement une base légère pour l'instant : pas encore de vrai modèle IA, pour éviter de consommer beaucoup de RAM trop tôt.

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

### Timer système

Le noyau installe maintenant une IDT, remappe le PIC et configure le PIT à environ 100 Hz.

Dans AstraOS :

```txt
uptime   Affiche le temps depuis le boot via le timer PIT
```

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
- [ ] Pilote clavier par interruptions
- [ ] Détection mémoire BIOS/E820
- [ ] Allocateur mémoire simple

### Phase 3 — Stockage et fichiers

- [ ] Lecture disque plus robuste
- [ ] Système de fichiers minimal
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
