; ============================================================================
; EREBUS — a sci-fi NES RPG (MMC1). Top-level: iNES header, includes, vectors.
;
; The generation ship EREBUS has drifted dark for 900 years. You are AXIOM,
; its caretaker intelligence, booted by an unknown signal into a maintenance
; android. Wake the ship. Learn what killed it. Decide who lives.
; ============================================================================
.include "defs.inc"

.segment "HEADER"
  .byte $4E, $45, $53, $1A       ; "NES"
  .byte 8                        ; 8 x 16K PRG = 128K
  .byte 16                       ; 16 x 8K CHR = 128K
  .byte $12                      ; mapper 1 (MMC1), vertical mirror flag
  .byte $00
  .byte 0,0,0,0,0,0,0,0

.segment "CODE"
.import reset, nmi, irq
.import main_init

; main entry — jumped to from reset (in boot.s)
.export main
main:
  jsr main_init
@hang:
  jmp @hang

.segment "VECTORS"
  .word nmi
  .word reset
  .word irq

.segment "CHARS"
  .incbin "../build/chr.bin"
