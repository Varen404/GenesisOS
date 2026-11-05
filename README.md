<<<<<<< HEAD
# GenesisOS
myOS
=======
# GENESIS

Système d'exploitation x86 écrit de zéro, en assembleur puis en C. C'est un projet d'école à visée pédagogique, orienté cybersécurité : chaque étape cherche à montrer comment une machine démarre, et où se placent les protections d'un système.

## Lancer le projet

Il faut `nasm`, `make` et `qemu-system-i386`.

```bash
make run
```

`make` construit l'image disque `build/genesis.img` sans la lancer, et `make clean` supprime les fichiers générés.

## Organisation

| Chemin | Rôle |
|---|---|
| `boot/boot.asm` | Secteur de boot : charge le kernel depuis le disque |
| `boot/print.inc` | Affichage de texte via le BIOS |
| `kernel/kernel.asm` | Kernel provisoire |
| `docs/` | Explication de chaque étape |

## Feuille de route

### Les fondations

- [x] Secteur de boot et affichage ([explications](docs/01-demarrage.md))
- [x] Chargement du kernel depuis le disque
- [ ] Passage en mode protégé 32 bits (GDT)
- [ ] Kernel en C et driver d'écran
- [ ] Interruptions, clavier et timer (IDT, PIC)
- [ ] Shell minimal : `help`, `clear`, `echo`, `uptime`, `reboot`

### La sécurité

- [ ] Vérification de l'intégrité du kernel au démarrage, pour refuser un kernel modifié
- [ ] Commandes d'inspection : `hexdump` de la mémoire, état des registres, écran de panique
- [ ] Pagination et protection de la mémoire
- [ ] Mode utilisateur (ring 3) et appels système
- [ ] Démonstration d'un dépassement de tampon dans un programme, puis de sa protection par un canari de pile
>>>>>>> b408a87 ([ADD]Basic bootloader, kernel and a makefile)
