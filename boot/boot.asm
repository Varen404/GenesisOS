; Secteur de boot de GENESIS.
; Le BIOS charge ce secteur de 512 octets a l'adresse 0x7C00 et lui donne la
; main en mode reel 16 bits. 512 octets ne suffisent pas pour un OS : son seul
; role est de charger le kernel, stocke juste apres lui sur le disque, puis de
; passer le processeur en mode protege 32 bits avant de lui donner la main.
; Details : docs/01-demarrage.md et docs/02-mode-protege.md

bits 16
org 0x7C00

; KERNEL_ADDRESS est fourni par le Makefile, qui le donne aussi au kernel : les
; deux doivent etre d'accord. Le BIOS, lui, attend une adresse segment:offset.
KERNEL_SEGMENT equ KERNEL_ADDRESS >> 4
KERNEL_OFFSET  equ KERNEL_ADDRESS & 0xF

; Sommet de la pile 32 bits. Elle descend vers le kernel, avec environ 500 Ko de
; marge, et reste sous la zone reservee par le BIOS vers 0x9FC00.
STACK_TOP equ 0x90000

; KERNEL_SECTORS est fourni par le Makefile d'apres la taille reelle du kernel.
%ifndef KERNEL_SECTORS
    %error "KERNEL_SECTORS doit etre defini (nasm -DKERNEL_SECTORS=n)"
%endif
%if KERNEL_SECTORS > 127
    %error "Kernel trop gros : certains BIOS refusent plus de 127 secteurs par lecture"
%endif

entry:
    jmp 0x0000:start            ; certains BIOS arrivent en 07C0:0000, on force CS=0

start:
    cli                         ; pas d'interruption pendant le changement de pile
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00              ; la pile descend sous notre code
    sti
    cld                         ; lodsb doit avancer dans la chaine

    mov [boot_drive], dl        ; le BIOS donne dans DL le disque d'ou il a boote

    mov ax, 0x0003              ; mode texte 80x25, efface aussi l'ecran
    int 0x10

    mov si, msg_hello
    call print

    ; Lecture du kernel avec les extensions disque du BIOS (int 0x13, AH=0x42).
    ; Le BIOS leve CF en cas d'echec, y compris si ces extensions n'existent pas.
    mov ah, 0x42
    mov dl, [boot_drive]
    mov si, dap
    int 0x13
    jc disk_error

    ; Active la ligne A20 (bit 1 du port 0x92), sinon le bit 20 de chaque adresse
    ; reste force a 0 et la memoire au-dela de 1 Mo est inaccessible.
    ; Le bit 0 de ce port redemarre la machine : on le garde a 0.
    in al, 0x92
    or al, 0x02
    and al, 0xFE
    out 0x92, al

    ; Point de non-retour : apres ces lignes, plus aucun service du BIOS.
    ; Il n'y a pas encore de table d'interruptions valide pour le mode protege :
    ; la moindre interruption redemarrerait la machine, d'ou le cli, sans sti.
    cli
    lgdt [gdt_descriptor]
    mov eax, cr0
    or eax, 1                   ; bit PE (Protection Enable)
    mov cr0, eax

    ; Le saut long recharge CS depuis la GDT et vide les instructions deja
    ; decodees en 16 bits. C'est lui qui fait reellement entrer en 32 bits.
    jmp CODE_SELECTOR:protected_start

disk_error:
    mov si, msg_disk_error
    call print

halt:
    cli
    hlt
    jmp halt                    ; hlt peut etre reveille par une NMI

%include "print.inc"

bits 32

protected_start:
    ; En mode protege, un registre de segment contient un selecteur de la GDT.
    ; Les valeurs du mode reel n'ont plus de sens : on les remplace toutes.
    mov ax, DATA_SELECTOR
    mov ds, ax
    mov es, ax
    mov fs, ax
    mov gs, ax
    mov ss, ax
    mov esp, STACK_TOP

    jmp KERNEL_ADDRESS

%include "gdt.inc"

; Disk Address Packet : decrit la lecture demandee au BIOS.
dap:
    db 0x10                     ; taille de cette structure
    db 0                        ; reserve
    dw KERNEL_SECTORS           ; nombre de secteurs a lire
    dw KERNEL_OFFSET            ; destination (offset, puis segment)
    dw KERNEL_SEGMENT
    dq 1                        ; LBA de depart : le secteur 0 est ce bootloader

boot_drive:     db 0
msg_hello:      db "Bonjour", 13, 10, 0
msg_disk_error: db "Erreur de lecture du disque", 13, 10, 0

times 510 - ($ - $$) db 0       ; complete le secteur jusqu'a 510 octets
dw 0xAA55                       ; signature exigee par le BIOS pour booter
