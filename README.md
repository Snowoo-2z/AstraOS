AstroOS

OpenSource.
For install : 

Un système d'exploitation x86 minimaliste développé à partir de zéro (*from scratch*).

## 💻 Compatibilité et Environnement

Cet OS tourne en **mode réel (x86 16-bit)** et est conçu pour s'exécuter dans un environnement d'émulation :

* **Émulateur recommandé :** QEMU (`qemu-system-x86_64`)
* **Architecture cible :** x86 (Intel / AMD)
* **Système hôte supporté :** Linux (Ubuntu / WSL2 sous Windows)

---

## 🛠️ Prérequis

Installe les outils requis sur ton système Linux / WSL :

```bash
sudo apt update
sudo apt install -y nasm qemu-system-x86
