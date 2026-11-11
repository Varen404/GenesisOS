# Étape 1 : du BIOS au kernel

Cette page explique ce qui se passe entre l'allumage de la machine et l'exécution du kernel. Le code correspondant se trouve dans [`boot/boot.asm`](../boot/boot.asm).

## Le déroulement

1. Le BIOS initialise la machine, puis lit le premier secteur du disque (512 octets).
2. Si ce secteur se termine par la signature `0xAA55`, le BIOS le copie à l'adresse `0x7C00` et lui donne la main.
3. Le secteur de boot prépare les registres, affiche `Bonjour`, puis lit le kernel sur le disque.
4. Il passe le processeur en 32 bits, puis saute à l'adresse du kernel ([étape 2](02-mode-protege.md)).

## Pourquoi deux programmes ?

Un secteur ne fait que 512 octets, signature comprise. C'est trop peu pour un système complet, donc le secteur de boot ne fait qu'une chose : charger un programme plus gros.

## L'organisation du disque

L'image `build/genesis.img` est une simple concaténation, découpée en secteurs de 512 octets :

| Secteur (LBA) | Contenu |
|---|---|
| 0 | Secteur de boot |
| 1 et suivants | Kernel |

Le Makefile calcule la taille du kernel en secteurs et la transmet à NASM avec `-DKERNEL_SECTORS=n`. Une taille écrite à la main serait dangereuse : le jour où le kernel grossit, sa fin ne serait plus chargée et le système planterait sans explication.

## L'organisation de la mémoire

| Adresse physique | Contenu |
|---|---|
| `0x00000` à `0x004FF` | Table des interruptions et données du BIOS, à ne pas écraser |
| `0x07C00` en descendant | Pile du mode réel |
| `0x07C00` à `0x07DFF` | Secteur de boot |
| `0x10000` et au-delà | Kernel |
| `0xB8000` | Mémoire de l'écran en mode texte |

## Le mode réel et les segments

Au démarrage, le processeur est en mode réel : il se comporte comme un 8086 de 1978, en 16 bits. Avec 16 bits, on n'atteint que 64 Ko, donc les adresses s'écrivent `segment:offset` et se calculent ainsi :

```
adresse physique = segment × 16 + offset
```

Le kernel est chargé à l'adresse `0x10000`, que le BIOS attend sous la forme `1000:0000` : `0x1000 × 16 + 0 = 0x10000`.

Ce système explique aussi le saut initial `jmp 0x0000:start`. Certains BIOS arrivent en `07C0:0000` et d'autres en `0000:7C00`. C'est la même adresse physique, mais pas les mêmes segments. Le saut long fixe `CS` à une valeur connue.

## La lecture du disque

Le BIOS fournit le service `int 0x13` avec `AH=0x42`. On lui décrit la lecture dans une petite structure, le Disk Address Packet (DAP) :

| Taille | Valeur | Rôle |
|---|---|---|
| 1 octet | `0x10` | Taille du DAP |
| 1 octet | `0` | Réservé |
| 2 octets | `KERNEL_SECTORS` | Nombre de secteurs à lire |
| 4 octets | `1000:0000` | Destination |
| 8 octets | `1` | Premier secteur à lire (LBA) |

Ce service adresse les secteurs par un simple numéro (LBA). L'ancien service `AH=0x02` demandait de calculer un cylindre, une tête et un secteur.

En cas d'échec, le BIOS lève le drapeau de retenue (`CF`). Le bootloader affiche alors `Erreur de lecture du disque` et s'arrête. Le test : démarrer une image réduite au seul secteur de boot, sans kernel, déclenche bien ce message.

## La pile

`mov sp, 0x7C00` place la pile juste sous le secteur de boot. Une pile descend vers les adresses basses, donc elle ne risque pas d'écraser le code.

Les interruptions sont coupées pendant que l'on change `SS` et `SP` : une interruption survenant entre les deux utiliserait une pile incohérente.

## L'angle sécurité

**Aucune vérification.** Le bootloader exécute tout ce qu'il trouve sur le disque, sans contrôle. Quiconque modifie le secteur 1 de l'image prend le contrôle de la machine avant que le système n'existe. C'est le principe d'un bootkit, et la raison d'être du Secure Boot sur les PC modernes.

**Aucune isolation.** En mode réel, tout programme peut lire et écrire toute la mémoire, y compris la table des interruptions. Il n'existe ni droits ni séparation entre le système et les programmes.

La feuille de route traite ces deux points : vérification de l'intégrité du kernel d'une part, mode protégé et pagination d'autre part. Une somme de contrôle stockée dans le secteur de boot détecte une modification du kernel, mais un attaquant capable de réécrire aussi le secteur de boot peut la contourner. C'est pourquoi une vraie chaîne de confiance s'appuie sur un élément que l'attaquant ne peut pas modifier.

## Questions pour s'entraîner

- Pourquoi `0xAA55` s'écrit-il `55 AA` dans le fichier ?
- Que se passerait-il si on retirait `cld` ?
- Pourquoi `KERNEL_SECTORS` est-il limité à 127 ?
- Pourquoi `hlt` est-il placé dans une boucle ?
