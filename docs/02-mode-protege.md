# Étape 2 : le mode protégé 32 bits

Cette page explique comment le processeur quitte le mode 16 bits hérité de 1978 pour le mode 32 bits. Le code se trouve dans [`boot/boot.asm`](../boot/boot.asm), [`boot/gdt.inc`](../boot/gdt.inc) et [`kernel/kernel.asm`](../kernel/kernel.asm).

## Ce que ça change

| | Mode réel | Mode protégé |
|---|---|---|
| Taille des registres | 16 bits | 32 bits |
| Mémoire accessible | 1 Mo | 4 Go |
| Registre de segment | Partie de l'adresse | Sélecteur d'une entrée de la GDT |
| Niveaux de privilège | Aucun | Rings 0 à 3 |
| Services du BIOS | Disponibles | Inaccessibles |

Le dernier point a une conséquence directe : le bootloader doit avoir tout lu sur le disque **avant** de changer de mode. Le kernel ne peut plus appeler `int 0x10`, il écrit donc directement dans la mémoire de l'écran.

## Le déroulement

1. Lire le kernel sur le disque, tant que le BIOS est disponible.
2. Activer la ligne A20.
3. Couper les interruptions avec `cli`.
4. Charger la GDT avec `lgdt`.
5. Mettre à 1 le bit PE du registre `CR0`.
6. Faire un saut long vers du code 32 bits.
7. Recharger les registres de segment et créer une pile.
8. Sauter au kernel.

## La ligne A20

Le 8086 n'avait que 20 lignes d'adresse, numérotées de A0 à A19. Une adresse au-delà de 1 Mo revenait à zéro, et certains programmes comptaient sur ce comportement. Pour rester compatibles, les PC suivants ont gardé la ligne A20 bloquée à 0 par défaut.

Tant qu'elle est bloquée, le bit 20 de chaque adresse est forcé à 0 : `0x100000` lit en réalité `0x000000`. Le kernel actuel tient sous 1 Mo, mais le système en aura besoin dès qu'il utilisera plus de mémoire.

On l'active par le port `0x92`, la méthode la plus courte. Certaines très vieilles machines ne la connaissent pas, ce qui ne pose pas de problème dans QEMU.

## La GDT

La Global Descriptor Table décrit les segments de la mémoire. Le processeur l'exige pour fonctionner en mode protégé. Elle contient ici trois entrées de 8 octets :

| Sélecteur | Entrée | Rôle |
|---|---|---|
| `0x00` | Nulle | Obligatoire : la charger dans un segment puis s'en servir provoque une erreur |
| `0x08` | Code | Instructions du kernel |
| `0x10` | Données | Variables et pile du kernel |

Un sélecteur est simplement le décalage de l'entrée dans la table. Après le passage, `CS` vaut donc `0x08` et les autres registres de segment `0x10`.

Les segments de code et de données commencent tous deux à l'adresse 0 et couvrent 4 Go. Ce modèle est dit « flat » : une adresse se lit directement, sans calcul de segment. Les systèmes modernes font de même et confient la protection de la mémoire à la pagination.

L'octet d'accès de l'entrée de code, `10011010b`, se lit ainsi :

| Bits | Valeur | Sens |
|---|---|---|
| 7 | `1` | Segment présent |
| 6-5 | `00` | Niveau de privilège (DPL) : ring 0 |
| 4 | `1` | Segment de code ou de données, pas un segment système |
| 3 | `1` | Exécutable |
| 2 | `0` | Accessible seulement depuis le ring 0 |
| 1 | `1` | Lisible |
| 0 | `0` | Bit « accédé », géré par le processeur |

L'octet suivant, `11001111b`, indique une limite comptée par blocs de 4 Ko et un segment 32 bits. Ce sont ces deux bits qui permettent d'atteindre 4 Go avec une limite de `0xFFFFF`.

## Pourquoi un saut long ?

Mettre le bit PE à 1 ne suffit pas à passer en 32 bits. Le processeur continue d'utiliser la description de `CS` chargée en mode réel, et ses instructions déjà décodées l'ont été en 16 bits.

Seul un saut long recharge `CS` depuis la GDT. C'est le rôle de `jmp CODE_SELECTOR:protected_start`.

Les autres registres de segment doivent ensuite être rechargés à la main, car ils contiennent encore des valeurs du mode réel.

## Pourquoi `cli` et jamais `sti` ?

En mode protégé, le processeur attend une IDT, une table d'interruptions dont le format diffère de celle du BIOS. Elle n'existe pas encore. La première interruption, celle du timer par exemple, n'a donc aucune destination valide.

L'expérience a été faite en ajoutant `sti` au kernel. Le journal de QEMU montre cette chaîne :

1. L'interruption provoque une erreur de protection générale (exception `0xD`).
2. Cette exception ne trouve pas non plus de destination, ce qui provoque une double faute (exception `0x8`).
3. La double faute échoue à son tour : c'est le **triple fault**.
4. Le processeur redémarre la machine.

Pour observer ce qui se passe lors d'un plantage, cette commande arrête QEMU au lieu de redémarrer et écrit tout dans un journal :

```bash
qemu-system-i386 -no-reboot -d int,cpu_reset -D qemu.log -drive format=raw,file=build/genesis.img
```

## Vérifier le résultat

Le message affiché est une première preuve : le kernel écrit à `0xB8000` sans aucun appel au BIOS. Pour une preuve complète, on interroge QEMU. Il faut lancer `make run`, ouvrir le moniteur avec `Ctrl+Alt+2`, puis taper `info registers` :

| Valeur observée | Signification |
|---|---|
| `CR0=00000011` | Le bit 0 (PE) vaut 1. Le bit 4 est toujours à 1 sur ces processeurs. |
| `CS =0008 ... CS32` | Le processeur exécute du code 32 bits depuis l'entrée de code de la GDT |
| `DS =0010` | Les données passent par l'entrée de données |
| `CPL=0` | Le code tourne en ring 0 |
| `A20=1` | La ligne A20 est active |
| `EIP=00010017` | Le processeur est dans le kernel, chargé à `0x10000` |
| `ESP=00090000` | La pile 32 bits est en place |

L'activation de A20 a été testée à part, car SeaBIOS, le BIOS de QEMU, l'active déjà de lui-même. On obtient `A20=0` en la coupant au démarrage, et `A20=1` si notre code passe ensuite.

Le curseur reste sur la deuxième ligne, sous le `M` du message : c'est le BIOS qui le déplaçait, et le kernel ne le gère pas encore. Le driver d'écran de l'étape suivante s'en chargera.

## L'angle sécurité

Malgré son nom, le mode protégé ne protège encore rien ici. Il fournit les mécanismes, et le système doit les utiliser.

**Tout tourne en ring 0.** `CPL=0` donne au code tous les droits : accès à toute la mémoire, aux ports matériels et aux instructions privilégiées comme `lgdt` ou `hlt`. Un programme lancé aujourd'hui pourrait tout détruire. La séparation viendra avec des segments de ring 3 et une structure appelée TSS.

**Rien n'empêche d'exécuter des données.** Comme les segments de code et de données couvrent la même mémoire, tout octet écrit sur la pile peut être exécuté. C'est exactement ce qu'exploite un dépassement de tampon classique avec du shellcode. La parade, W^X (une page n'est jamais à la fois inscriptible et exécutable), passe par la pagination. En 32 bits, le bit NX qui la rend possible demande en plus le mode PAE.

**Toute erreur redémarre la machine.** Sans IDT, un bug provoque un triple fault sans laisser de trace. Pour un défenseur, c'est le pire des cas : aucun diagnostic possible. L'IDT permettra d'attraper ces erreurs et d'afficher un écran de panique.

**Le ring 0 décide de tout.** La GDT se trouve en mémoire, et rien ne l'y protège. Tout code du ring 0 peut la réécrire et changer les règles. C'est pour cela qu'un rootkit vise le kernel : une fois à ce niveau, plus aucune protection logicielle ne tient.

## Questions pour s'entraîner

- Pourquoi le kernel ne peut-il plus utiliser `int 0x10` ?
- Que vaudrait `CS` si on chargeait une GDT dont l'entrée de code serait la troisième ?
- Que se passerait-il en retirant le saut long ?
- Pourquoi garder le bit 0 du port `0x92` à 0 ?
- Pourquoi le modèle « flat » n'apporte-t-il aucune protection de la mémoire ?
- Pourquoi `lgdt` doit-elle être une instruction privilégiée ?
