; Kernel provisoire de GENESIS : il prouve que le processeur est en mode protege
; 32 bits. Il sera remplace par un kernel en C a l'etape suivante.
; Le bootloader a deja prepare les segments et la pile. Les interruptions restent
; coupees, et ne devront etre reactivees qu'une fois une IDT en place.

bits 32
org KERNEL_ADDRESS

VGA_MEMORY equ 0xB8000          ; memoire de l'ecran en mode texte
VGA_COLUMNS equ 80
WHITE_ON_BLACK equ 0x0F

kernel_start:
    cld
    mov esi, msg_protected
    mov edi, VGA_MEMORY + VGA_COLUMNS * 2 ; ligne 1, sous le message du bootloader
    mov ah, WHITE_ON_BLACK

    ; Plus de BIOS ici : chaque case de l'ecran fait 2 octets, le caractere (AL)
    ; puis sa couleur (AH), et stosw ecrit les deux d'un coup en memoire video.
.next:
    lodsb
    test al, al
    jz halt
    stosw
    jmp .next

halt:
    hlt
    jmp halt                    ; hlt peut etre reveille par une NMI

; 0x82 est le "e accent aigu" de la page de code CP437 des ecrans VGA.
msg_protected: db "Mode prot", 0x82, "g", 0x82, " 32 bits actif", 0
