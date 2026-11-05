; Affiche la chaine terminee par 0 pointee par DS:SI, via le service teletype
; du BIOS (int 0x10, AH=0x0E). Ne fonctionne qu'en mode reel : les services du
; BIOS ne sont plus accessibles une fois en mode protege.
print:
    lodsb                       ; AL = [DS:SI], puis SI++ (d'ou le cld au demarrage)
    test al, al
    jz .done
    mov ah, 0x0E
    xor bh, bh                  ; page video 0
    int 0x10
    jmp print
.done:
    ret
