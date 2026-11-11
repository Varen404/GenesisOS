; Global Descriptor Table : decrit les segments utilisables en mode protege.
; Chaque entree fait 8 octets et le processeur impose ce decoupage en morceaux,
; herite du 286. Les deux segments couvrent les 4 Go de la memoire (modele
; "flat") : on garde l'obligation d'avoir une GDT sans s'en servir pour decouper
; la memoire. Details : docs/02-mode-protege.md

gdt_start:
    dq 0                        ; entree nulle, exigee par le processeur

gdt_code:                       ; code du kernel
    dw 0xFFFF                   ; limite, bits 0-15
    dw 0x0000                   ; base, bits 0-15
    db 0x00                     ; base, bits 16-23
    db 10011010b                ; present, ring 0, code, executable, lisible
    db 11001111b                ; granularite 4 Ko, 32 bits, limite bits 16-19
    db 0x00                     ; base, bits 24-31

gdt_data:                       ; donnees et pile du kernel
    dw 0xFFFF
    dw 0x0000
    db 0x00
    db 10010010b                ; present, ring 0, donnees, inscriptible
    db 11001111b
    db 0x00

gdt_end:

; Valeur chargee par lgdt : taille de la table moins 1, puis son adresse.
gdt_descriptor:
    dw gdt_end - gdt_start - 1
    dd gdt_start

; Un selecteur est le decalage de l'entree dans la table.
CODE_SELECTOR equ gdt_code - gdt_start
DATA_SELECTOR equ gdt_data - gdt_start
