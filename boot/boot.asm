; Secteur de boot de GENESIS.
; Le BIOS charge ce secteur de 512 octets a l'adresse 0x7C00 et lui donne la
; main en mode reel 16 bits. 512 octets ne suffisent pas pour un OS : son seul
; role est de charger le kernel, stocke juste apres lui sur le disque.
; Details : docs/01-demarrage.md

bits 16
org 0x7C00

; Le kernel est charge en 1000:0000, soit l'adresse physique 0x10000.
KERNEL_SEGMENT equ 0x1000
KERNEL_OFFSET  equ 0x0000

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

    mov dl, [boot_drive]        ; le kernel recoit le disque de boot dans DL
    jmp KERNEL_SEGMENT:KERNEL_OFFSET

disk_error:
    mov si, msg_disk_error
    call print

halt:
    cli
    hlt
    jmp halt                    ; hlt peut etre reveille par une NMI

%include "print.inc"

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
