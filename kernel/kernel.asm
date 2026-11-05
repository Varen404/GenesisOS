; Kernel provisoire de GENESIS : il prouve que le chargement depuis le disque
; fonctionne. Il tourne encore en mode reel et sera remplace par un kernel
; 32 bits en C (etapes 2 et 3 de la feuille de route).

bits 16
org 0                           ; le bootloader saute en 1000:0000

kernel_start:
    mov ax, cs                  ; CS vaut deja 0x1000 apres le saut long
    mov ds, ax                  ; DS doit suivre pour atteindre nos donnees
    mov es, ax

    mov si, msg_loaded
    call print

halt:
    cli
    hlt
    jmp halt

%include "print.inc"

; 0x82 est le "e accent aigu" de la page de code CP437 des ecrans VGA.
msg_loaded: db "Kernel charg", 0x82, " depuis le disque", 13, 10, 0
